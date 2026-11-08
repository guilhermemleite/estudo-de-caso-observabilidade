require 'sinatra'
require 'json'
require 'prometheus/client'
require 'prometheus/middleware/exporter'

# --- OpenTelemetry ---
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

# Sem buffer: logs chegam imediatamente ao Docker/Alloy/Loki
$stdout.sync = true

set :port, 4567
set :bind, '0.0.0.0'

# --- Métricas Prometheus (RED) ---
PROM = Prometheus::Client.registry

HTTP_REQUESTS = PROM.counter(
  :http_requests_total,
  docstring: 'Total de requisições HTTP',
  labels: [:method, :route, :status]
)

HTTP_DURATION = PROM.histogram(
  :http_request_duration_seconds,
  docstring: 'Latência das requisições HTTP em segundos',
  labels: [:method, :route],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5]
)

PRODUCTS_VIEWED = PROM.counter(:products_viewed_total, docstring: 'Total de produtos visualizados')
ORDERS_CREATED  = PROM.counter(:orders_created_total,  docstring: 'Total de pedidos criados')

# Serve /metrics no formato de exposição do Prometheus
use Prometheus::Middleware::Exporter

# Lista fechada de rotas: evita explosão de cardinalidade no label "route"
KNOWN_ROUTES = ['/products', '/orders', '/admin/chaos'].freeze

# --- Injeção de falhas (chaos) ---
# Valores iniciais por env; alteráveis em tempo real via POST /admin/chaos
CHAOS_ROUTES = ['/products', '/orders'].freeze
CHAOS_LOCK   = Mutex.new
$chaos = {
  'error_rate' => ENV.fetch('CHAOS_ERROR_RATE', '0').to_f,  # 0.0 a 1.0
  'latency_ms' => ENV.fetch('CHAOS_LATENCY_MS', '0').to_i   # latência média extra
}

# --- Dados simulados ---
$products = [
  { id: 1, name: 'Produto A', price: 29.99 },
  { id: 2, name: 'Produto B', price: 49.99 }
]
$orders = []
ORDERS_LOCK = Mutex.new

# --- Filtros ---
before do
  @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  next unless CHAOS_ROUTES.include?(request.path_info)

  chaos = CHAOS_LOCK.synchronize { $chaos.dup }

  # Latência injetada com variação de ±50%
  if chaos['latency_ms'] > 0
    sleep(chaos['latency_ms'] * rand(0.5..1.5) / 1000.0)
  end

  # Erro injetado com a probabilidade configurada
  if rand < chaos['error_rate']
    halt 500, { 'Content-Type' => 'application/json' },
         { error: 'chaos: falha injetada' }.to_json
  end
end

after do
  next if request.path_info == '/health'   # healthcheck fora das métricas RED

  method  = request.request_method
  route   = KNOWN_ROUTES.include?(request.path_info) ? request.path_info : 'unmatched'
  status  = response.status
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at

  HTTP_REQUESTS.increment(labels: { method: method, route: route, status: status.to_s })
  HTTP_DURATION.observe(elapsed, labels: { method: method, route: route })

  # Log estruturado (logfmt) correlacionado com o trace
  ctx = OpenTelemetry::Trace.current_span.context
  next unless ctx.valid?

  level = status >= 500 ? 'error' : 'info'
  puts "level=#{level} msg=\"request completed\" " \
       "method=#{method} path=#{request.path_info} status=#{status} " \
       "duration_ms=#{(elapsed * 1000).round(2)} " \
       "traceID=#{ctx.hex_trace_id} spanID=#{ctx.hex_span_id}"
end

# --- Rotas ---
get '/health' do
  content_type :json
  { status: 'ok', timestamp: Time.now }.to_json
end

get '/products' do
  content_type :json
  PRODUCTS_VIEWED.increment
  $products.to_json
end

post '/orders' do
  content_type :json
  data = JSON.parse(request.body.read)

  order = ORDERS_LOCK.synchronize do
    o = { id: $orders.length + 1, product_id: data['product_id'], timestamp: Time.now }
    $orders << o
    o
  end
  ORDERS_CREATED.increment

  # Atributos de negócio no span atual (aparecem no Tempo)
  span = OpenTelemetry::Trace.current_span
  span.set_attribute('order.id', order[:id])
  span.set_attribute('order.product_id', order[:product_id].to_i)

  order.to_json
end

# --- Administração do chaos ---
get '/admin/chaos' do
  content_type :json
  CHAOS_LOCK.synchronize { $chaos.dup }.to_json
end

post '/admin/chaos' do
  content_type :json
  data = JSON.parse(request.body.read)
  CHAOS_LOCK.synchronize do
    $chaos['error_rate'] = data['error_rate'].to_f.clamp(0.0, 1.0)  if data.key?('error_rate')
    $chaos['latency_ms'] = data['latency_ms'].to_i.clamp(0, 10_000) if data.key?('latency_ms')
    $chaos.dup
  end.to_json
end
