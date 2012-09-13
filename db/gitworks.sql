CREATE TABLE job (
  id BIGINT UNSIGNED NOT NULL,
  created BIGINT UNSIGNED NOT NULL DEFAULT 0,

  repository_url VARBINARY(1023) NOT NULL,
  repository_branch VARBINARY(1023) NOT NULL,
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

CREATE TABLE repository_set (
  id BIGINT UNSIGNED NOT NULL,
  created BIGINT UNSIGNED NOT NULL DEFAULT 0,

  set_name VARBINARY(127) NOT NULL,
  repository_url VARBINARY(511) NOT NULL,
  PRIMARY KEY (id),
  KEY (created),
  UNIQUE KEY (set_name, repository_url),
  KEY (set_name, created),
  KEY (repository_url, created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE repository (
  id BIGINT UNSIGNED NOT NULL,
  created BIGINT UNSIGNED NOT NULL,
  repository_url VARBINARY(511) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY (repository_url),
  KEY (created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE commit_status (
  id BIGINT UNSIGNED NOT NULL,
  created DOUBLE NOT NULL,
  repository_id BIGINT UNSIGNED NOT NULL,
  sha VARBINARY(40) NOT NULL,
  `state` TINYINT UNSIGNED NOT NULL,
  target_url VARBINARY(511) NOT NULL,
  description VARBINARY(511) NOT NULL,
  PRIMARY KEY (id),
  KEY (repository_id, sha, created),
  KEY (repository_id, created),
  KEY (created)
) DEFAULT CHARSET=BINARY;
