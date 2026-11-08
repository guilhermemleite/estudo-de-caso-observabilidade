require 'sinatra'
require 'json'

# --- OpenTelemetry --------------------------------------------------------
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/rack'
require 'opentelemetry/instrumentation/sinatra'

# Endpoint e nome do serviço vêm das variáveis OTEL_* do docker-compose
OpenTelemetry::SDK.configure do |c|
  c.use 'OpenTelemetry::Instrumentation::Rack',
        { untraced_endpoints: ['/health', '/metrics'] }
  c.use 'OpenTelemetry::Instrumentation::Sinatra'
end
# --------------------------------------------------------------------------

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

  # Atributos de negócio no span atual (aparecem no Tempo)
  span = OpenTelemetry::Trace.current_span
  span.set_attribute('order.id', order[:id])
  span.set_attribute('order.product_id', order[:product_id].to_i)

  order.to_json
end

# Endpoint de métricas para Prometheus
get '/metrics' do
  content_type 'text/plain; version=0.0.4'

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

  metrics_output.join("\n") + "\n"
end

# --- Log estruturado com correlação de trace ------------------------------
# Sem isso, o Ruby faz buffer do stdout fora de um terminal e os logs
# chegam atrasados (ou nunca) no Docker/Alloy/Loki.
$stdout.sync = true

after do
  ctx = OpenTelemetry::Trace.current_span.context
  next unless ctx.valid?   # /health e /metrics não têm trace (untraced)

  puts "level=info msg=\"request completed\" " \
       "method=#{request.request_method} path=#{request.path_info} " \
       "status=#{response.status} " \
       "traceID=#{ctx.hex_trace_id} spanID=#{ctx.hex_span_id}"
end
