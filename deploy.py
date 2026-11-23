import base64, glob, json, subprocess, sys
files = ["vercel.json", "404.html", "index.html", "comecar.html", "painel.html", "site.html", "reserva.html", "termos.html", "privacidade.html", "app.js", "app.css", "config.js", "img/favicon-guara.png"]
files += sorted(glob.glob("img/**/*.jpg", recursive=True))  # fotos das pousadas publicadas junto com o site
body = {"name": "pousada-gestao", "target": "production",
        "files": [{"file": f, "data": base64.b64encode(open(f, "rb").read()).decode(), "encoding": "base64"} for f in files],
        "projectSettings": {"framework": None, "buildCommand": None, "outputDirectory": None, "installCommand": None}}
open("/tmp/deploy_pousada.json", "w").write(json.dumps(body))
out = subprocess.run(["curl", "-sS", "-X", "POST", "https://api.vercel.com/v13/deployments?skipAutoDetectionConfirmation=1", "-H", "Content-Type: application/json", "--data", "@/tmp/deploy_pousada.json"], capture_output=True, text=True).stdout
d = json.loads(out)
if "error" in d: print("ERRO", d["error"]); sys.exit(1)
print("id", d.get("id"), "| state", d.get("readyState"), "| alias", d.get("alias"), "| project", d.get("projectId"))
