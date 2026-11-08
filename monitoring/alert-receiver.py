"""Receptor mínimo de webhooks do Alertmanager.
Grava cada alerta em logfmt no stdout (coletado pelo Alloy -> Loki)."""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        size = int(self.headers.get("Content-Length", 0))
        payload = json.loads(self.rfile.read(size) or b"{}")
        channel = self.path.strip("/") or "default"

        for alert in payload.get("alerts", []):
            labels = alert.get("labels", {})
            summary = alert.get("annotations", {}).get("summary", "").replace('"', "'")
            status = alert.get("status", "unknown")
            level = "error" if status == "firing" else "info"
            print(
                f'level={level} msg="alert {status}" channel={channel} '
                f'alertname={labels.get("alertname", "-")} slo={labels.get("slo", "-")} '
                f'severity={labels.get("severity", "-")} summary="{summary}"',
                flush=True,
            )

        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):  # silencia o access log padrão
        pass


HTTPServer(("0.0.0.0", 5001), Handler).serve_forever()
