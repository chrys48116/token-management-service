FROM elixir:1.16.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git postgresql-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=dev

RUN mix local.hex --force \
    && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get

COPY . .

EXPOSE 4000

CMD ["bash", "-c", "until pg_isready -h ${DB_HOST:-db} -U ${DB_USERNAME:-postgres}; do sleep 1; done; mix ecto.setup && mix phx.server"]
