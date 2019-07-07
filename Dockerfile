FROM jekyll/jekyll

WORKDIR /website
COPY Gemfile .
COPY Gemfile.lock .

RUN bundle install

CMD ["jekyll", "serve"]