require 'sinatra'
require 'json'

set :port, 4567
set :bind, '0.0.0.0'

# Dados simulados
$products = [
  { id: 1, name: 'Produto A', price: 29.99 },
  { id: 2, name: 'Produto B', price: 49.99 }
]

$orders = []

# Contadores simples para métricas
$metrics = {
  http_requests: 0,
  products_viewed: 0,
  orders_created: 0
}

# Middleware simples para contar requisições
before do
  $metrics[:http_requests] += 1
end

# Health check
get '/health' do
  content_type :json
  { status: 'ok', timestamp: Time.now }.to_json
end

# Listar produtos
get '/products' do
  content_type :json
  $metrics[:products_viewed] += 1
  $products.to_json
end

# Criar pedido
post '/orders' do
  content_type :json
  data = JSON.parse(request.body.read)
  
  order = {
    id: $orders.length + 1,
    product_id: data['product_id'],
    timestamp: Time.now
  }
  
  $orders << order
  $metrics[:orders_created] += 1
  
  order.to_json
end

# Endpoint de métricas para Prometheus
get '/metrics' do
  content_type 'text/plain'
  
  metrics_output = []
  metrics_output << "# HELP http_requests_total Total HTTP requests"
  metrics_output << "# TYPE http_requests_total counter"
  metrics_output << "http_requests_total #{$metrics[:http_requests]}"
  
  metrics_output << "# HELP products_viewed_total Total products viewed"
  metrics_output << "# TYPE products_viewed_total counter"
  metrics_output << "products_viewed_total #{$metrics[:products_viewed]}"
  
  metrics_output << "# HELP orders_created_total Total orders created"
  metrics_output << "# TYPE orders_created_total counter"
  metrics_output << "orders_created_total #{$metrics[:orders_created]}"
  
  metrics_output.join("\n")
end

