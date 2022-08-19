---
title: "Extending Dapr's publish & subscribe to client-side apps"
image: "/img/thumbnails/dapr-client-msg.png"
bigimg: "/img/mails.jpg"
tags: [.NET,Azure,Containers,DevOps,Kubernetes]
---

[Dapr](https://dapr.io/) (Distributed Application Runtime) helps with typical challenges that arise when building portable and reliable microservices. It uses sidecars that run next to your app and provide a uniform API for service invocation, publish & subscribe, secret & state management and more. 

With that you don't need to include specific logic for message brokers, state/secret stores or observability backends into your microservices. This all happens transparently by Dapr and you can easily switch between implementations by only changing configurations.

This works great for communication between microservices. But what if you got a client-side application where you can't run the sidecar?

## TL;DR

Dapr bindings are okay to use when there are only a few events to catch, but for extensive asynchronous messaging between your client-side app and your microservices this is unmanageable.

As Dapr uses CloudEvents for publish & subscribe between microservices your client-side app can publish events directly to the message broker and make them appear as if they had been sent from another microservice via Dapr. In your microservice you can therefore use the default Dapr APIs as long as the messages from the client-side app conform to the CloudEvents specification.

For example in a .NET microservice using the `Dapr.AspNetCore` SDK you can subscribe to client-side events by simply adding a `Topic` annotation just like you would do for service-to-service publish & subscribe communication:
```csharp
app.MapPost("/ping", [Topic("kafka-pubsub", "ping")](dynamic inputOrder) => Results.Ok());
```

On the client-side you simply need to make sure to conform to the CloudEvents specification so that your events can be deserialized by your microservice:
```typescript
await producer.send({
    topic: 'ping',
    messages: [
        CeKafka.structured(new CloudEventStrict({
            specversion: Version.V1,
            source: 'some-source',
            id: 'some-id',
            type: 'message.send',
            data: {
                orderId: "123"
            },
        })),
    ],
})
```

On the client-side you of course loose the benefits of abstraction provided by Dapr. But if you're already using Dapr for all your service-to-service communication in your backend then sticking to the same communication model for your client-server communication is definitively recommendable.

Read on for a full walk through an example and look at the source code of it [on GitHub](https://github.com/lippertmarkus/dapr-clientside)!


## The problem with Dapr bindings

For communication with external systems Dapr recommends the use of [bindings](https://docs.dapr.io/developing-applications/building-blocks/bindings/bindings-overview/). With [input bindings](https://docs.dapr.io/developing-applications/building-blocks/bindings/howto-triggers/) you can configure Dapr to listen to a specific topic and send a request to an endpoint of your microservice for each event received.

If you only need to catch a few events this is feasible, but if you want to have extensive asynchronous messaging between your client-side app and your microservices this quickly gets unmanageable as you would either need to create bindings for every endpoint of your microservice or send all requests to the same endpoint and route them accordingly in your service by yourself. But there's a better way!


## Tricking Dapr publish & subscribe to work with client-side apps

Dapr allows for asynchronous publish & subscribe communication between microservices and uses [CloudEvents](https://cloudevents.io/) for that. CloudEvents is a specification for events which defines a default structure and metadata. This means that no matter what message broker is configured for Dapr, the events are always structured the same way. 

Most of that happens transparently through Dapr itself: The publisher gives their message/object to Dapr, Dapr wraps it into the CloudEvents structure, adds additional metadata and tracing information and sends it to the configured message broker. On the receiver side the Dapr sidecar subscribed to the topic receives the message, deserializes it and sends only the payload to the endpoint of the microservice.

Now you may get the idea: If our client-side application is structuring the event it publishes exactly like the Dapr sidecar of a publisher microservice would, the receiver microservice won't recognize that the publisher is a client-side app and will happily receive the event.

This way our microservice can use the same logic it uses to receive messages from other microservices for receiving messages from client-side apps as well. Let's walk through an example.

## Example walkthrough

If you haven't already, first [install Dapr](https://docs.dapr.io/getting-started/install-dapr-cli/):

```bash
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
dapr init
```

For testing our asynchronous publish & subscribe communication we run a Kafka instance locally via Docker Compose:
```bash
curl -sSL https://raw.githubusercontent.com/lippertmarkus/dapr-clientside/main/docker-compose.yml > docker-compose.yml
docker-compose up -d
```

To allow our microservice to receive messages from the Kafka message broker we just started, we configure it as a Dapr component by creating the file `~/.dapr/components/kafka-pubsub.yaml`:
```yml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: kafka-pubsub
spec:
  type: pubsub.kafka
  version: v1
  metadata:
  - name: brokers
    value: localhost:9092
  - name: authType
    value: "none"
```

Now we can create our microservice and our client-side app.

### Server-side microservice

There are Dapr SDKs for many languages, in our example we will create a .NET minimal web API and use the Dapr SDK for ASP.NET. You can create the microservice with the following commands:

```bash
mkdir daprtest
cd daprtest

dotnet new webapi -minimal -o dummyapi1
cd dummyapi1
dotnet add package Dapr.AspNetCore
```

A minimal example for an API with an endpoint that is triggered on incoming events looks like the following:
```csharp
using Dapr;

var builder = WebApplication.CreateBuilder(args);
//builder.Services.AddDaprClient(); // only needed if you do other things with Dapr than subscribing to messages
var app = builder.Build();
app.UseCloudEvents();
app.MapSubscribeHandler();
app.MapPost("/ping", [Topic("kafka-pubsub", "ping")](dynamic inputOrder)
    =>
{
    Console.WriteLine($"WE GOT: {inputOrder}");
    return Results.Ok();
});
app.Run();
```

With `MapSubscribeHandler()` we're enabling Dapr subscriptions and specify to use the CloudEvents format with `UseCloudEvents()`. Afterwards we can simply annotate our endpoints (lambdas in this minimal example or methods when using Controller classes) with the `Topic` annotation. Here `kafka-pubsub` corresponds to the component name we specified in the YAML above and `ping` is the topic we want to subscribe to. 

Take a moment to appreciate that you don't need any broker-specific logic here, Dapr handles all that for you transparently. To run our microservice together with the Dapr sidecar you can execute:
```bash
dapr run --app-id dummyapi1 --app-port 7002 -- dotnet run --urls "http://localhost:7002"
```

Now on to the client-side application.

### Client-side app

As an example client-side app we will create a node application with TypeScript. Use the following commands to initialize it:

```bash
cd ..
mkdir dummyclientapp
cd dummyclientapp
npm init esnext -y
npm i typescript tsx @types/node --save-dev
npm i cloudevents cloudevents-kafka kafkajs --save
npx tsc --init --module es2022 --target es2022
npm set-script start "npx tsx index.ts"
```

As you can see from the dependencies we add, the missing possibility to run the sidecar on the client comes with a downside: we can't benefit from the abstractions and decoupling Dapr brings with it. Instead, we need to add broker-specific logic to our application. In a production app you should of course at least abstract this by your own using interfaces to make switching to another message broker more easily if needed.

To keep the example simple, I didn't do that here. We connect to the Kafka message broker by using the `kafkajs` package and use `cloudevents-kafka` to send a CloudEvents conform message to the `ping` topic our microservice subscribes to:

```typescript
import { Version } from 'cloudevents'
import { Kafka } from 'kafkajs'
import * as CeKafka from "cloudevents-kafka"
const { CloudEventStrict } = CeKafka

let kafka = new Kafka({
    clientId: 'mypublisher',
    brokers: ['localhost:9092']
})

let producer = kafka.producer()
await producer.connect()
await producer.send({
    topic: 'ping',  // use the same topic as in your endpoint annotation
    messages: [
        CeKafka.structured(new CloudEventStrict({
            specversion: Version.V1,
            source: 'some-source',
            id: 'some-id',
            type: 'message.send',
            data: {  // this data is received by your endpoint
                orderId: "123"
            },
        })),
    ],
})
``` 

Now start your client application with `npm start` and observe the logs of the microservice to see that the message was successfully received:

```diff
INFO[0002] app is subscribed to the following topics: [ping] through pubsub=kafka-pubsub  app_id=dummyapi1 instance=Markus-Laptop scope=dapr.runtime type=log ver=1.8.4
INFO[0002] dapr initialized. Status: Running. Init Elapsed 2275.1313ms  app_id=dummyapi1 instance=Markus-Laptop scope=dapr.runtime type=log ver=1.8.4
+== APP == WE GOT: {"orderId":"123"}
```

## Conclusion

Dapr is great with simplifying challenges around microservice architectures. If you're already using Dapr for your service-to-service communications and want to extend this onto client applications, you should look at the described way to stay consistent. You can find the full source code of the example [on GitHub](https://github.com/lippertmarkus/dapr-clientside/tree/main).

The limitation of this approach is that it gives you the abstractions and decoupling on the server side only, but it's still better than not having it on both sides or needing to implement it on your own. The approach can certainly be extended to be more decoupled on the client side as well and to add support e.g. for tracing.
