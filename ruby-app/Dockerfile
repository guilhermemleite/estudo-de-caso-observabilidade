FROM ruby:3.2-slim

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiar Gemfile
COPY Gemfile ./

# Instalar gems
RUN bundle install

# Copiar código da aplicação
COPY . .

EXPOSE 4567

CMD ["ruby", "app.rb"]

