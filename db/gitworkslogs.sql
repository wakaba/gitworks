CREATE TABLE log (
  id BIGINT UNSIGNED NOT NULL,
  created DOUBLE NOT NULL,
  repository_id BIGINT UNSIGNED NOT NULL,
  repository_branch VARBINARY(511) NOT NULL,
  sha VARBINARY(40) NOT NULL,
  `data` MEDIUMBLOB NOT NULL,
  PRIMARY KEY (id),
  KEY (created),
  KEY (repository_id, repository_branch, created),
  KEY (repository_id, sha, created),
  KEY (repository_id, created)
) DEFAULT CHARSET=BINARY;
