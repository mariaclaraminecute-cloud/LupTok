-- Rode primeiro e confira o resultado. Se houver duplicados, corrija-os antes de criar o índice.
SELECT LOWER(nome_usuario) AS usuario_normalizado, COUNT(*) AS quantidade
FROM usuario
GROUP BY LOWER(nome_usuario)
HAVING COUNT(*) > 1;

-- Execute SOMENTE se a consulta acima não retornar linhas e se ainda não existir índice único equivalente:
ALTER TABLE usuario ADD UNIQUE KEY uq_usuario_nome_usuario (nome_usuario);
