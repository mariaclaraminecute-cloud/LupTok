CREATE TABLE video_post_curtida (
  id_usuario INT UNSIGNED NOT NULL,
  id_video BIGINT UNSIGNED NOT NULL,
  data_curtida DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_usuario, id_video),
  KEY idx_video_post_curtida_video (id_video),
  CONSTRAINT fk_video_post_curtida_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
    ON DELETE CASCADE,
  CONSTRAINT fk_video_post_curtida_video
    FOREIGN KEY (id_video) REFERENCES video_post (id_video)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE denuncia
  ADD COLUMN id_video BIGINT UNSIGNED NULL AFTER id_postagem,
  ADD UNIQUE KEY uq_denuncia_denunciante_video (id_denunciante, id_video),
  ADD KEY idx_denuncia_id_video (id_video),
  ADD CONSTRAINT fk_denuncia_video_post
    FOREIGN KEY (id_video) REFERENCES video_post (id_video)
    ON DELETE SET NULL;
