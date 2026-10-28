#!/usr/bin/env python3
"""Servidor de mentira para probar la app SIN tocar producción.

  python3 tool/mock_server.py            # escucha en 127.0.0.1:8099
  flutter run -d <sim> --dart-define=API_BASE_URL=http://127.0.0.1:8099

Controles (desde un navegador o curl):
  /_admin/offline?on=1   corta las conexiones sin responder (simula sin señal)
  /_admin/offline?on=0   vuelve a responder
  /_admin/state          resultados y alumnos guardados hasta ahora
  /_admin/reset          borra los resultados guardados
Mismo contrato que el servidor real para lo que usa la pantalla de calificación.
"""
import json, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

STUDENTS = [
    dict(id=1, testStudentId=101, num=1, firstName="Juan", lastName="Perez", email="j@x.com", present=True, levelName="Practitioner 1", levelCode="P1", fail=False),
    dict(id=2, testStudentId=102, num=2, firstName="Maria", lastName="Gomez", email="m@x.com", present=True, levelName="Practitioner 1", levelCode="P1", fail=False),
    dict(id=3, testStudentId=103, num=3, firstName="Pedro", lastName="Lopez", email="p@x.com", present=True, levelName="Practitioner 1", levelCode="P1", fail=False),
]
MISTAKES = [dict(id=11, name="Mala guardia"), dict(id=12, name="Sin balance"), dict(id=13, name="Muy lento")]
TECHS = [dict(id=i, techniqueId=i, name=n, code=c, score=10.0, sort=i, mistakes=MISTAKES)
         for i, (c, n) in enumerate([("P1-01", "Straight punch"), ("P1-02", "Palm strike"), ("P1-03", "Knee strike")], 1)]

state = dict(offline=False, next_id=1000, results={}, student_fail={}, log=[], finished=False)

def detail():
    groups = {}
    for (t, s), r in state["results"].items():
        groups.setdefault(t, []).append(dict(studentId=s, resultId=r["ID"], mistakeId=r["TEST_LEVEL_FAIL_ID"],
            passed=bool(r["PASSED"]), isFail=False, freeText=r["FREE_TEXT"]))
    students = [dict(s, fail=state["student_fail"].get(s["testStudentId"], False)) for s in STUDENTS]
    return dict(id=500, name="MOCK Practitioner 1", status=2, country=dict(id=1, name="Mockland"),
                center=dict(id=1, name="Mock Center"), students=students, techniques=TECHS,
                results=[dict(techniqueId=t, results=v) for t, v in groups.items()])

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def _drop(self):
        self.close_connection = True
        self.connection.close()
    def _route(self, method):
        u = urlparse(self.path); q = parse_qs(u.query)
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n) if n else b""
        if u.path == "/_admin/offline":
            state["offline"] = q.get("on", ["1"])[0] == "1"; return self._send(200, dict(offline=state["offline"]))
        if u.path == "/_admin/state":
            return self._send(200, dict(results=[dict(technique=t, student=s, **r) for (t, s), r in state["results"].items()],
                                        studentFail=state["student_fail"], finished=state["finished"], log=state["log"]))
        if u.path == "/_admin/reset":
            state.update(results={}, student_fail={}, log=[]); return self._send(200, {})
        if state["offline"]:
            return self._drop()
        if u.path == "/token":
            return self._send(200, dict(access_token="mock", id="1", name="Mock Instructor", email="mock@x.com", paymentstatus="1"))
        if u.path == "/api/instructors/countries":
            return self._send(200, [dict(id=1, name="Mockland", flag="", centers=[dict(id=1, name="Mock Center")])])
        if u.path == "/api/tests":
            return self._send(200, [dict(id=500, name="MOCK Practitioner 1", date="2026-10-28T00:00:00", participants=3, failed=0, status=2)])
        if u.path == "/api/tests/500":
            return self._send(200, detail())
        if u.path.startswith("/api/getTestResults/"):
            return self._send(200, dict(testId=500, testName="MOCK Practitioner 1", totalPassed=1, totalFailed=1, totalCondition=1,
                students=[dict(studentId=s["id"], firstName=s["firstName"], lastName=s["lastName"], levelCode="P1",
                               shirtNum=s["num"], totalPoints=90 - 10*s["id"], result="pass", results=[]) for s in STUDENTS]))
        if u.path == "/api/sync/SyncTestStatus":
            state["log"].append(dict(t=time.strftime("%H:%M:%S"), testStatus=json.loads(body))); state["finished"] = True
            return self._send(200, {})
        if u.path == "/api/sync/SyncStudentsResults":
            items = json.loads(body)
            for it in items:
                k = (it["LEVELID"], it["TEST_STUDENT_ID"])
                state["log"].append(dict(t=time.strftime("%H:%M:%S"), item=it))
                if "ID" not in it and k in state["results"]:
                    return self._send(500, dict(error="duplicate key"))  # clave única, como el real
                rid = it.get("ID") or state["next_id"]
                if "ID" not in it: state["next_id"] += 1
                state["results"][k] = dict(it, ID=rid)
                if "FAIL" in it: state["student_fail"][it["TEST_STUDENT_ID"]] = bool(it["FAIL"])
            return self._send(200, {})
        self._send(404, dict(error=u.path))
    def do_GET(self): self._route("GET")
    def do_POST(self): self._route("POST")

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8099
    print(f"mock en http://127.0.0.1:{port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
