-- =============================================================================
-- Vê AI · SELECTs que comprovam o CRUD no Azure SQL (vídeo da entrega de DevOps)
-- Tabelas demonstradas: RELATO e DESCRICAO (as duas têm Create, Read, Update e Delete pela API).
--
-- Rodar tudo:      bash scripts/sql.sh -f database/crud-verification.sql
-- Rodar um bloco:  copie a consulta e use  bash scripts/sql.sh "SELECT ..."
-- O roteiro (docs/roteiro-video.md) diz qual SELECT mostrar depois de cada operação no Swagger.
-- Datas no horário de Brasília (o banco guarda em UTC).
-- =============================================================================
SET NOCOUNT ON;

PRINT '== Contagem por tabela (antes e depois do CRUD) ==';
SELECT 'relato' AS tabela, COUNT(*) AS linhas FROM relato
UNION ALL SELECT 'descricao', COUNT(*) FROM descricao
UNION ALL SELECT 'usuario', COUNT(*) FROM usuario
UNION ALL SELECT 'notificacao', COUNT(*) FROM notificacao;

PRINT '== RELATO: últimos 5 (CREATE aparece aqui; UPDATE muda texto/gravidade/atualizado_em; DELETE some) ==';
SELECT TOP 5 r.id, u.email AS cidadao, g.nome AS regiao, r.tipo, r.gravidade, r.status,
       LEFT(r.texto, 60) AS texto, r.endereco, r.total_apoios, r.prioridade,
       FORMAT(SWITCHOFFSET(r.criado_em, '-03:00'), 'dd/MM HH:mm:ss') AS criado, FORMAT(SWITCHOFFSET(r.atualizado_em, '-03:00'), 'dd/MM HH:mm:ss') AS atualizado
FROM relato r
JOIN usuario u ON u.id = r.cidadao_id
JOIN regiao g ON g.id = r.regiao_id
ORDER BY r.id DESC;

PRINT '== DESCRICAO: últimas 5 (CREATE aparece aqui; UPDATE = avaliação "util"; DELETE some) ==';
SELECT TOP 5 d.id, u.email AS cidadao, d.modo, LEFT(d.resumo, 60) AS resumo, d.barreira_detectada,
       d.barreira_tipo, d.util, d.latencia_ms, FORMAT(SWITCHOFFSET(d.criado_em, '-03:00'), 'dd/MM HH:mm:ss') AS criado
FROM descricao d
JOIN usuario u ON u.id = d.usuario_id
ORDER BY d.id DESC;

PRINT '== Notificações geradas pelo consumidor RabbitMQ para os últimos relatos ==';
SELECT TOP 5 n.id, n.relato_id, u.email AS destinatario, LEFT(n.mensagem, 70) AS mensagem, n.lida
FROM notificacao n
JOIN usuario u ON u.id = n.usuario_id
ORDER BY n.id DESC;

-- -----------------------------------------------------------------------------
-- Consultas por id, para usar logo depois de cada operação (troque o número pelo id do Swagger):
--
--   bash scripts/sql.sh "SELECT id, tipo, gravidade, status, texto, endereco, atualizado_em FROM relato WHERE id = 16"
--   bash scripts/sql.sh "SELECT COUNT(*) AS existe FROM relato WHERE id = 16"            -- 0 depois do DELETE
--   bash scripts/sql.sh "SELECT id, modo, resumo, util, criado_em FROM descricao WHERE id = 21"
--   bash scripts/sql.sh "SELECT COUNT(*) AS existe FROM descricao WHERE id = 21"         -- 0 depois do DELETE
--
-- Histórico do Flyway (prova de que o schema veio da migração V1 = scripts/script-bd.sql):
--   bash scripts/sql.sh "SELECT installed_rank, version, description, success FROM flyway_schema_history"
-- -----------------------------------------------------------------------------
