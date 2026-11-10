# Roteiro do vídeo · DevOps Tools & Cloud Computing

**Requisitos técnicos:** 720p ou mais, áudio claro, **narração por voz** (sem legendas no lugar da fala), **sem cortes**, publicado no YouTube (público ou não listado).
Cada item obrigatório omitido custa −20. Os itens abaixo seguem a ordem do enunciado.

## Antes de gravar

- [ ] Infra no ar e o último deploy verde (Build e Release)
- [ ] `bash scripts/sql.sh --liberar-ip` (o firewall precisa do seu IP atual)
- [ ] Terminal no WSL aberto na pasta do repositório, fonte grande
- [ ] Abas abertas: README no Azure Repos, Portal Azure no Resource Group, Boards, Pipelines, Swagger da nuvem
- [ ] Token da Ana já copiado (`POST /auth/login` com `ana.souza@veai.dev` / `Veai@2026`) e colado em **Authorize** no Swagger
- [ ] Uma foto pequena em JPEG à mão (por exemplo `postman/foto-calcada.jpg`) para o CRUD de descrição
- [ ] Ensaiar uma vez inteira (o Build com os testes de integração leva alguns minutos; fale sobre os testes enquanto ele roda)

## Sequência (sem cortes)

| # | Mostrar | Falar |
|---|---|---|
| 1 | **README** no Azure Repos: a solução, o desenho da arquitetura (`docs/img/diagrama-arquitetura.png`) | O que é o Vê AI; o fluxo numerado: Boards → Repos → Build → Release → App Service + Azure SQL, CloudAMQP e OpenAI; segredos no Variable Group |
| 2 | **Portal Azure** → Resource Group `561413-veai-devops-rg`: App Service Plan, Web App, SQL server e banco `veai` | "Tudo isso foi criado pelo `scripts/01-create-infra.sh`, só com Azure CLI." Abra rapidamente o script e o `script-bd.sql` na pasta `/scripts` |
| 3 | **Boards** → nova Task, por exemplo "Versão 1.1.0 da API: destacar o modo automático no Swagger" | Por que a Task vem antes da branch |
| 4 | Na Task, **Create a branch** (`feature/versao-1-1`), e no VS Code faça a alteração **no código** (abaixo) | A alteração é em código Java, não no README |
| 5 | Commit `AB#<id da task> versão 1.1.0 no OpenAPI` → push → **Pull Request** para a `main` com a Task vinculada | Políticas da `main`: revisor obrigatório (RM561413), work item vinculado, sem push direto |
| 6 | Aprovar e completar o PR (**merge**) | O merge na `main` é o gatilho do Build |
| 7 | **Pipelines → veai-build** rodando sozinho: Java 21, cache, conferência do `script-bd.sql`, `mvn clean verify` | Os 66 testes rodam com SQL Server e RabbitMQ reais em container |
| 8 | Build concluído: abas **Tests** (66 aprovados), **Code Coverage** e o artefato **drop** (`target/ve-ai-api.jar` + scripts) | Se um teste falhar, não há artefato e a Release não roda |
| 9 | **veai-release** disparando sozinha por causa do artefato novo: stage **Deploy** (App Settings + `az webapp deploy` + health) e **SmokeTest** | Segredos vêm do Variable Group (mostre o cadeado na Library, sem revelar valores) |
| 10 | **Swagger na nuvem** (`https://561413-veai-api.azurewebsites.net/swagger-ui.html`): a versão **1.1.0** e o texto novo no topo | A alteração do código está publicada |
| 11 | **CRUD de RELATO** com SELECT depois de cada operação (abaixo) | "Não uso GET para provar persistência: confiro com SELECT direto no Azure SQL" |
| 12 | **CRUD de DESCRICAO** com SELECT depois de cada operação (abaixo) | Segunda tabela |
| 13 | **Boards** → a Task: aba **Development** com branch, commits, PR e build; mude para **Done** | Rastreabilidade completa |

## Alteração no código (item 4)

Em `src/main/java/br/com/fiap/veai/config/OpenApiConfig.java`:

```java
.version("1.1.0")
.description("""
        Assistente para pessoas com deficiência visual: narra o caminho enquanto a pessoa anda \
        (modo automático, perigos primeiro) e transforma barreiras de acessibilidade em relatos \
        para a rede de apoio. Mesmo contrato nas versões Java e .NET.""")
```

Aparece no topo do Swagger logo depois do deploy, sem depender de dados.

## CRUD de RELATO (item 11)

Swagger com o token da Ana. Depois de cada operação, rode o SELECT no terminal (troque `ID` pelo id retornado).

| Operação | No Swagger | SELECT |
|---|---|---|
| **Create** | `POST /relatos` com o corpo abaixo → `201`, `resultado: CRIADO` | `bash scripts/sql.sh "SELECT id, tipo, gravidade, status, texto, endereco FROM relato WHERE id = ID"` |
| **Read** | `GET /relatos/{id}` | o mesmo SELECT: os valores batem com o JSON |
| **Update** | `PUT /relatos/{id}` com `gravidade: ALTA` e outro texto | `bash scripts/sql.sh "SELECT id, gravidade, texto, atualizado_em FROM relato WHERE id = ID"` |
| **Delete** | `DELETE /relatos/{id}` → `204` | `bash scripts/sql.sh "SELECT COUNT(*) AS existe FROM relato WHERE id = ID"` → `0` |

```json
{
  "tipo": "RAMPA",
  "gravidade": "MEDIA",
  "texto": "Rampa da faixa de pedestres termina em degrau.",
  "latitude": -23.561234,
  "longitude": -46.656789,
  "endereco": "Av. Paulista, 1000"
}
```

Use um ponto **diferente** a cada ensaio (mude a 4ª casa decimal): a regra dos 30 m transforma um relato igual e próximo em apoio, e um relato com apoio não pode ser excluído.

Depois do Create, mostre também as notificações geradas pelo consumidor RabbitMQ: `bash scripts/sql.sh "SELECT TOP 3 id, relato_id, mensagem FROM notificacao ORDER BY id DESC"`.

## CRUD de DESCRICAO (item 12)

| Operação | No Swagger | SELECT |
|---|---|---|
| **Create** | `POST /descricoes`: escolha a foto em `imagem`, `modo = AMBIENTE` → `201` (a IA real descreve a foto) | `bash scripts/sql.sh "SELECT id, modo, resumo, util FROM descricao WHERE id = ID"` |
| **Read** | `GET /descricoes/{id}` | o mesmo SELECT |
| **Update** | `PATCH /descricoes/{id}/avaliacao` com `{"util": true}` | o mesmo SELECT: `util` passou de `NULL` para `1` |
| **Delete** | `DELETE /descricoes/{id}` → `204` | `bash scripts/sql.sh "SELECT COUNT(*) AS existe FROM descricao WHERE id = ID"` → `0` |

Para uma visão geral antes e depois: `bash scripts/sql.sh -f database/crud-verification.sql`.

## Encerramento

Volte à Task no Boards (estado **Done**) e mostre os links de branch, commits, PR e build. Fim da gravação.
