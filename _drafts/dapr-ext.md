---
title: "TODO"
image: "/img/thumbnails/TODO.png"
bigimg: "/img/TODO.jpg"
tags: [TODO]
---




using bindings has downsides
- new binding for every endpoint or send all requests so same endpoint


better with pubsub through cloudevents

```bash
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash

dapr init

mkdir daprtest

dotnet new webapi -minimal -o dummyapi1

# run kafka
curl -sSL TODOGITHUBREPO/docker-compose.yml > docker-compose.yml
docker-compose up -d

cd dummyapi1
dotnet add package Dapr.AspNetCore
```


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

`Program.cs`:
```csharp
using Dapr;
//builder.Services.AddDaprClient(); // TODO only needed if i want to send

var app = WebApplication.CreateBuilder(args).Build();
app.UseCloudEvents();
app.MapSubscribeHandler();
app.MapPost("/ping", [Topic("kafka-pubsub", "ping")](dynamic inputOrder)
    =>
{
    Console.WriteLine($"WE GOOOT: {inputOrder}");
    return Results.Ok();
});
app.Run();
```

```
dapr run --app-id dummyapi1 --app-port 7002 -- dotnet run --urls "http://localhost:7002"
```

```
mkdir dummyclientapp
cd dummyclientapp
npm i typescript tsx --save
npm install --save-dev @types/node
npx tsc --init
npm set-script start "npx tsx index.ts"


npm install cloudevents cloudevents-kafka kafkajs
```



```
npm start
```