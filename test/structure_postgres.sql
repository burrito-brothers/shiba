CREATE TABLE users (
  id serial NOT NULL,
  organization_id int DEFAULT NULL,
  email varchar(255) NOT NULL,
  name varchar(255) DEFAULT '',
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL,
  PRIMARY KEY (id)
);

create index index_users_on_organization_id on users (organization_id);

CREATE TABLE organizations (
  id serial NOT NULL,
  name varchar(255) DEFAULT '',
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE comments (
  id serial NOT NULL,
  user_id int NOT NULL,
  body text NOT NULL,
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL,
  PRIMARY KEY (id)
);

create index index_comments_on_user_id on comments (user_id);
