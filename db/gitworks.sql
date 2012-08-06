CREATE TABLE job (
  id BIGINT UNSIGNED NOT NULL,
  created BIGINT UNSIGNED NOT NULL DEFAULT 0,

  repository_url VARBINARY(1023) NOT NULL,
  repository_revision VARBINARY(1023) NOT NULL,
  action_type VARBINARY(127) NOT NULL,
  args BLOB NOT NULL,
  
  process_started BIGINT UNSIGNED NOT NULL DEFAULT 0,
  process_id BIGINT UNSIGNED NOT NULL,

  PRIMARY KEY (id),
  KEY (created),
  KEY (process_id, process_started),
  KEY (process_started)
) DEFAULT CHARSET=BINARY;
