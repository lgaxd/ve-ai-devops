"""Gera docs/img/diagrama-arquitetura.png: arquitetura macro + fluxo CI/CD numerado + legenda.
Uso (da raiz do repositório): python docs/gerar_diagrama.py    (requer Pillow: pip install pillow)"""
import os

from PIL import Image, ImageDraw, ImageFont

W, H = 1920, 1340
img = Image.new("RGB", (W, H), "white")
d = ImageDraw.Draw(img)
FONTES = "C:/Windows/Fonts/"


def F(tamanho, negrito=False):
    nome = "arialbd.ttf" if negrito else "arial.ttf"
    for caminho in (FONTES + nome, "/usr/share/fonts/truetype/dejavu/DejaVuSans" + ("-Bold" if negrito else "") + ".ttf"):
        if os.path.exists(caminho):
            return ImageFont.truetype(caminho, tamanho)
    return ImageFont.load_default()


AZUL, LARANJA, VERDE, ROXO, CINZA, VERMELHO, TEAL = "#1f5fbf", "#d9680f", "#1f8a4c", "#6b3fa0", "#555555", "#b3261e", "#0f7c8c"


def caixa(x1, y1, x2, y2, fundo, linha, titulo, linhas=()):
    d.rounded_rectangle((x1, y1, x2, y2), radius=18, fill=fundo, outline=linha, width=3)
    d.text(((x1 + x2) // 2, y1 + 16), titulo, font=F(24, True), fill=linha, anchor="mt")
    y = y1 + 56
    for t in linhas:
        d.text(((x1 + x2) // 2, y), t, font=F(19), fill="#222222", anchor="mt")
        y += 27


def seta(pontos, cor, largura=4):
    for a, b in zip(pontos, pontos[1:]):
        d.line((a, b), fill=cor, width=largura)
    (x0, y0), (x1, y1) = pontos[-2], pontos[-1]
    dx = (x1 > x0) - (x1 < x0)
    dy = (y1 > y0) - (y1 < y0)
    s = 13
    if dx:
        d.polygon([(x1, y1), (x1 - dx * s * 1.6, y1 - s), (x1 - dx * s * 1.6, y1 + s)], fill=cor)
    else:
        d.polygon([(x1, y1), (x1 - s, y1 - dy * s * 1.6), (x1 + s, y1 - dy * s * 1.6)], fill=cor)


def numero(x, y, n, cor):
    d.ellipse((x - 19, y - 19, x + 19, y + 19), fill=cor, outline="white", width=2)
    d.text((x, y), str(n), font=F(21, True), fill="white", anchor="mm")


def rotulo(x, y, t, cor, ancora="mm"):
    d.text((x, y), t, font=F(18), fill=cor, anchor=ancora)


d.text((W // 2, 16), "Vê AI · Arquitetura macro e fluxo CI/CD (Azure DevOps + Azure)", font=F(32, True), fill="#222", anchor="mt")

# ---- Linha 1: equipe e Azure DevOps ---------------------------------------------------------
y1, y2 = 80, 250
caixa(30, y1, 250, y2, "#f2f2f2", CINZA, "Equipe", ["VS Code / WSL", "Git"])
caixa(320, y1, 590, y2, "#f3ecfa", ROXO, "Azure Boards", ["Task (Scrum)", "vinculada a branch,", "commits e PR"])
caixa(660, y1, 960, y2, "#f3ecfa", ROXO, "Azure Repos (Git)", ["main protegida:", "PR + revisor + work item"])
caixa(1030, y1, 1420, y2, "#eaf1fc", AZUL, "Build (CI)", ["azure-pipeline.yml · trigger: main", "mvn verify · 66 testes JUnit", "SQL Server + RabbitMQ (containers)", "publica JaCoCo e o artefato drop"])
caixa(1490, y1, 1890, y2, "#eaf1fc", AZUL, "Release (CD)", ["azure-pipeline-release.yml", "dispara com o novo artefato", "Deploy + SmokeTest"])
seta([(250, 165), (320, 165)], CINZA); numero(285, 130, 1, CINZA)
seta([(590, 165), (660, 165)], ROXO); numero(625, 130, 2, ROXO)
seta([(960, 165), (1030, 165)], AZUL); numero(995, 130, 3, AZUL)
seta([(1420, 165), (1490, 165)], AZUL); numero(1455, 130, 4, AZUL)

# Variable Group e espelho
caixa(1640, 300, 1890, 410, "#fff8e5", VERMELHO, "Variable Group", ["veai-devops-secrets", "(valores secretos)"])
seta([(1765, 300), (1765, 250)], VERMELHO); numero(1810, 275, 5, VERMELHO)
caixa(30, 300, 470, 395, "#efefef", CINZA, "GitHub (espelho)", ["lgaxd/ve-ai-devops · a cada merge"])
seta([(810, 250), (810, 275), (250, 275), (250, 300)], CINZA); numero(530, 275, 11, CINZA)

# ---- Azure -----------------------------------------------------------------------------------
d.rounded_rectangle((30, 460, 1500, 1010), radius=24, fill="#fafbfd", outline="#7a8aa0", width=3)
d.text((55, 474), "Microsoft Azure · 561413-veai-devops-rg (criado por Azure CLI)", font=F(22, True), fill="#44546a", anchor="la")
caixa(70, 540, 470, 830, "#fdf1e7", LARANJA, "Scripts Azure CLI (/scripts)", ["01-create-infra.sh", "app-settings.sh · deploy-app.sh", "smoke-test.sh · sql.sh", "script-bd.sql (DDL)", "99-delete-infra.sh", ".env.azure fora do Git"])
caixa(560, 540, 1000, 830, "#fff4ea", LARANJA, "App Service (Web App)", ["561413-veai-api", "Linux B1 · Java 21", "Spring Boot 4 · JWT · Swagger", "Spring AI · Spring AMQP", "/health (db, rabbit, openai)", "App Settings = segredos"])
caixa(1090, 540, 1460, 770, "#eaf7f0", VERDE, "Azure SQL Database", ["561413-veai-sql / veai", "PaaS · Basic 5 DTU", "9 tabelas (Flyway V1", "= script-bd.sql)", "contained user veai_app", "firewall: Azure + IP"])
seta([(470, 685), (560, 685)], LARANJA); rotulo(515, 660, "cria", LARANJA)
seta([(270, 830), (270, 860), (1420, 860), (1420, 770)], LARANJA, 2); rotulo(780, 878, "cria (servidor, banco, firewall, usuário)", LARANJA)
seta([(1000, 640), (1090, 640)], VERDE); seta([(1090, 700), (1000, 700)], VERDE)
rotulo(1045, 612, "JDBC", VERDE); rotulo(1045, 725, "TLS", VERDE); numero(1045, 670, 9, VERDE)

# Release -> Web App
seta([(1550, 250), (1550, 440), (780, 440), (780, 540)], AZUL)
numero(1460, 440, 6, AZUL)
rotulo(1130, 425, "az webapp deploy do JAR + health check + smoke test", AZUL)

d.text((70, 905), "Segredos: Variable Group → variáveis de ambiente da pipeline → App Settings do Web App", font=F(19, True), fill=VERMELHO, anchor="la")
d.text((70, 935), "Nada de senha no código, nos YAMLs ou no Git (.env e .env.azure são ignorados)", font=F(18), fill="#444", anchor="la")
d.text((70, 970), "Prova do CRUD (RELATO e DESCRICAO): bash scripts/sql.sh → SELECT direto no Azure SQL", font=F(19, True), fill=VERDE, anchor="la")

# ---- Serviços externos -----------------------------------------------------------------------
caixa(1560, 480, 1890, 640, "#e7f6f8", TEAL, "CloudAMQP", ["RabbitMQ gerenciado", "exchange veai.relatos", "fila veai.notificacoes + DLQ"])
caixa(1560, 690, 1890, 850, "#e7f6f8", TEAL, "OpenAI", ["Spring AI · gpt-6-luna", "descrição da foto", "(saída estruturada)"])
seta([(1000, 580), (1030, 580), (1030, 510), (1530, 510), (1530, 560), (1560, 560)], TEAL, 3)
numero(1070, 510, 10, TEAL); rotulo(1300, 494, "AMQPS: eventos e notificações", TEAL)
seta([(1000, 805), (1530, 805), (1530, 770), (1560, 770)], TEAL, 3)
rotulo(1220, 789, "HTTPS: foto → descrição", TEAL)

# ---- Usuários --------------------------------------------------------------------------------
caixa(760, 1080, 1190, 1180, "#f2f2f2", CINZA, "Usuários", ["app mobile · Swagger (professor)"])
seta([(975, 1080), (975, 830)], CINZA); numero(1015, 1045, 8, CINZA); rotulo(1075, 1045, "HTTPS", CINZA)
d.text((1240, 1110), "7  A cada deploy a API sobe, o Flyway confere o schema e o /health fica UP", font=F(18), fill=AZUL, anchor="la")

# ---- Legenda ---------------------------------------------------------------------------------
d.rounded_rectangle((30, 1210, 1890, 1325), radius=14, fill="#fcfcfc", outline="#bbbbbb", width=2)
d.text((50, 1222), "Legenda", font=F(20, True), fill="#333", anchor="la")
itens = [(ROXO, "Azure Boards / Repos"), (AZUL, "Azure Pipelines (CI/CD)"), (LARANJA, "Infra criada por Azure CLI"),
         (VERDE, "Banco PaaS (Azure SQL)"), (TEAL, "Serviços externos"), (VERMELHO, "Segredos"), (CINZA, "Pessoas e espelho")]
x = 50
for cor, texto in itens:
    d.rounded_rectangle((x, 1262, x + 30, 1290), radius=6, fill=cor)
    d.text((x + 40, 1276), texto, font=F(17), fill="#333", anchor="lm")
    x += 265
d.text((1870, 1222), "Números = ordem do fluxo (docs/architecture.md)", font=F(17), fill="#555", anchor="ra")

saida = os.path.join(os.path.dirname(os.path.abspath(__file__)), "img", "diagrama-arquitetura.png")
os.makedirs(os.path.dirname(saida), exist_ok=True)
img.save(saida)
print("ok", saida, img.size)
