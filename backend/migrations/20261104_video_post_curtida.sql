-- Compatível com a estrutura atual: não recria o banco nem video_post.
CREATE TABLE IF NOT EXISTS video_post_curtida (
  id_usuario BIGINT UNSIGNED NOT NULL,
  id_video BIGINT UNSIGNED NOT NULL,
  criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_usuario, id_video),
  INDEX idx_video_post_curtida_video (id_video),
  CONSTRAINT fk_video_post_curtida_video
    FOREIGN KEY (id_video) REFERENCES video_post (id_video) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
