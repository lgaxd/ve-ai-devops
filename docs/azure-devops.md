# Passo a passo: Azure (infra) e Azure DevOps

Ordem recomendada. Tudo roda no WSL (Ubuntu) ou Git Bash, com a Azure CLI logada na **assinatura do Pietro**.

## 0. Ferramentas

```bash
az version                      # Azure CLI
sqlcmd --version                # go-sqlcmd (instruções em scripts/lib.sh, função require_sqlcmd)
python3 --version               # usado pelos scripts para montar os App Settings sem expor valores
```

## 1. Infraestrutura na Azure (Azure CLI)

```bash
cp .env.azure.example .env.azure     # preencha as senhas, JWT, OpenAI e a URL do CloudAMQP (arquivo fora do Git)
az login                             # conta do Pietro
az account show -o table             # confira a assinatura
bash scripts/01-create-infra.sh
```

O script cria, nesta ordem: Resource Group `561413-veai-devops-rg` → servidor `561413-veai-sql` e banco `veai` (Basic) → firewall (serviços do Azure + seu IP) → contained user `veai_app` → plano `561413-veai-plan` (Linux B1) → Web App `561413-veai-api` (Java 21) com os App Settings.

- Se aparecer erro de política ou região (`RequestDisallowedByAzure`), troque `LOCATION=southafricanorth` no `.env.azure`, apague o grupo vazio (`az group delete -n 561413-veai-devops-rg --yes`) e rode de novo.
- No fim, o script imprime o `DB_URL` que vai para o Variable Group.

Primeiro deploy manual (opcional, para testar antes das pipelines):

```bash
./mvnw clean package -DskipTests
bash scripts/deploy-app.sh target/ve-ai-api.jar
bash scripts/smoke-test.sh
```

## 2. Projeto no Azure DevOps

Organização **`https://dev.azure.com/RM561469`** → **New project**:

| Campo | Valor |
|---|---|
| Project name | `VeAI-DevOps` |
| Description | Global Solution 2026/2 · DevOps Tools & Cloud Computing · Vê AI. Integrantes: 561413 - Lucas Grillo Alcântara; 561469 - Pietro Ferreira Gomes Abrahamian; 561792 - Pedro Peres Benitez; 562027 - Lucca Ramos Mussumecci (2TDSPX) |
| Visibility | **Private** |
| Version control | Git |
| Work item process | Scrum |

### Acesso do professor

1. **Organization settings → Users → Add users:** e-mail do professor, Access level **Basic**.
2. **Project settings → Permissions → Project Administrators → Members → Add:** o professor.
3. Adicione também o Lucas (RM561413) como membro do projeto (ele é o revisor padrão da `main`).

## 3. Azure Repos

```bash
# na pasta DevOps (já é um repositório Git com a branch main)
git remote add origin https://RM561469@dev.azure.com/RM561469/VeAI-DevOps/_git/VeAI-DevOps
git push -u origin main
```

### Políticas da branch `main`

**Repos → Branches → `main` → ⋯ → Branch policies:**

| Política | Valor |
|---|---|
| Require a minimum number of reviewers | **On**, mínimo 1, **Allow requestors to approve their own changes** marcado (o enunciado permite) |
| Check for linked work items | **On**, Required |
| Check for comment resolution | On (opcional) |
| Automatically included reviewers | **Lucas Grillo Alcântara (RM561413)**, Required |
| Build validation | não adicionar: o Build deve rodar só depois do merge, não no PR |

Com a política ativa, ninguém consegue dar push direto na `main`: toda mudança entra por PR.

## 4. Service connection

**Project settings → Service connections → New → Azure Resource Manager → Workload identity federation (automatic):**

- Scope level: Subscription (a do Pietro), Resource group `561413-veai-devops-rg`
- Name: **`sc-veai-devops`**
- Marque **Grant access permission to all pipelines** (ou autorize na 1ª execução)

## 5. Variable Group

**Pipelines → Library → + Variable group → `veai-devops-secrets`**. Marque o cadeado (secreto) em todos os valores sensíveis:

| Variável | Valor | Secreta |
|---|---|---|
| `DB_URL` | impresso pelo script 01 (`jdbc:sqlserver://561413-veai-sql.database.windows.net:1433;database=veai;...`) | sim |
| `DB_USER` | `veai_app` | sim |
| `DB_PASSWORD` | igual ao `.env.azure` | sim |
| `JWT_SECRET` | igual ao `.env.azure` | sim |
| `OPENAI_API_KEY` | chave da OpenAI | sim |
| `RABBITMQ_URL` | URL `amqps://` da instância do CloudAMQP de DevOps | sim |
| `SMOKE_EMAIL` | `ana.souza@veai.dev` | não |
| `SMOKE_SENHA` | `Veai@2026` | sim |
| `GITHUB_PAT` | token do GitHub (fine-grained, só `lgaxd/ve-ai-devops`, Contents: Read and write) | sim |
| `GITHUB_REPO` | `github.com/lgaxd/ve-ai-devops` | não |

## 6. Pipelines

**Pipelines → New pipeline → Azure Repos Git → VeAI-DevOps → Existing Azure Pipelines YAML file**, três vezes:

| Arquivo | Renomear para (⋯ → Rename/move) |
|---|---|
| `/azure-pipeline.yml` | **`veai-build`** |
| `/azure-pipeline-release.yml` | **`veai-release`** (o nome precisa bater com `source: veai-build` do YAML) |
| `/azure-pipeline-mirror.yml` | **`veai-mirror-github`** |

Na primeira execução, a Release pede permissão para usar o Variable Group, a service connection e o ambiente `veai-producao`: clique em **View → Permit** (uma vez só).

Para o espelho: crie antes o repositório vazio `lgaxd/ve-ai-devops` no GitHub.

## 7. Conferência final

- [ ] Um PR de teste: Task no Boards → branch → commit `AB#<id>` → PR com a Task → aprovação → merge
- [ ] `veai-build` rodou sozinho, com a aba **Tests** (66 testes) e **Code Coverage** preenchidas e o artefato **drop**
- [ ] `veai-release` disparou sozinha depois do Build, com Deploy e SmokeTest verdes
- [ ] `https://561413-veai-api.azurewebsites.net/swagger-ui.html` abre
- [ ] `bash scripts/sql.sh -f database/crud-verification.sql` mostra os dados do seed
- [ ] O commit apareceu em `github.com/lgaxd/ve-ai-devops`
- [ ] O professor consegue abrir Boards, Repos e Pipelines
