# rails6-multidb-sample

次のことを確認するためのサンプルアプリケーションです。

- PostgreSQL の非同期レプリケーション
- Rails 6.0 の Multiple DBs 機能
- DatabaseSelector を使った HTTP Method による接続先自動切り替え

## 試す

```bash
$ docker-compose up
```

```bash
$ docker-compose exec app bundle exec rails db:setup
```

Open http://localhost:3000/posts

## PostgreSQL の非同期レプリケーション

Docker Compose を使って、2 つの PostgreSQL コンテナを立ち上げます。
一方をレプリケーションの parimary に、もう一方を readonly (Hot Standby) として使います。

## Rails 6.0 の Multiple DBs 機能

[Active Record で複数のデータベース利用](https://railsguides.jp/active_record_multiple_databases.html)

次のようにレプリケーションの parimary （読み書き可能）と readonly （読み込み専用）を `host` で指定します。
YAML 中の `primary` `primary_readonly` は後で参照するのに使う識別子で任意に設定可能です。

```yaml
development:
  primary:
    <<: *default
    database: MyApp_development
    host: pg_primary
  primary_readonly:
    <<: *default
    database: MyApp_development
    host: pg_readonly
    replica: true   # この接続はレプリカであることRailsに伝える
```

```ruby
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: { writing: :primary, reading: :primary_readonly }
end
```

```ruby
ActiveRecord::Base.connected_to(role: :writing) do
  # このブロック内のコードはすべて writing ロールで接続される
  ActiveRecord::Base.current_role #=> :writing
end

ActiveRecord::Base.connected_to(role: :reading) do
  # このブロック内のコードはすべて reading ロールで接続される
  ActiveRecord::Base.current_role #=> :reading
end
```

## DatabaseSelector を使った HTTP Method による接続先自動切り替え

`config/environments/development.rb` で以下を設定しています。

```ruby
config.active_record.database_selector = { delay: 2.seconds }
config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
```

[コネクションの自動切り替えを有効にする - Active Record で複数のデータベース利用](https://railsguides.jp/active_record_multiple_databases.html#%E3%82%B3%E3%83%8D%E3%82%AF%E3%82%B7%E3%83%A7%E3%83%B3%E3%81%AE%E8%87%AA%E5%8B%95%E5%88%87%E3%82%8A%E6%9B%BF%E3%81%88%E3%82%92%E6%9C%89%E5%8A%B9%E3%81%AB%E3%81%99%E3%82%8B)

### 試してみる

http://localhost:3000/posts で記事を登録したり、表示したりすると次のようなログが表示され、どちらのデータベースにクエリが送信されたか確認できます。

```
app_1          | Started PATCH "/posts/1" for 172.21.0.1 at 2019-10-03 18:37:22 +0000
app_1          | Cannot render console from 172.21.0.1! Allowed networks: 127.0.0.0/127.255.255.255, ::1
pg_primary_1   | 2019-10-03 18:37:22.227 UTC [66] LOG:  statement: SELECT 1
app_1          | Processing by PostsController#update as HTML
app_1          |   Parameters: {"authenticity_token"=>"tJBhu5R3jC6vI+SubacKMK4bAyLUi62Tq5GkXpI/jhwPPLlpzC546Nwmaurjgp45kFieKwScCboGzkXgsC71cw==", "post"=>{"title"=>"Hello world!!", "body"=>"one two three"}, "commit"=>"Update Post", "id"=>"1"}
pg_primary_1   | 2019-10-03 18:37:22.229 UTC [66] LOG:  statement: SHOW search_path
pg_primary_1   | 2019-10-03 18:37:22.230 UTC [66] LOG:  execute a1: SELECT "posts".* FROM "posts" WHERE "posts"."id" = $1 LIMIT $2
pg_primary_1   | 2019-10-03 18:37:22.230 UTC [66] DETAIL:  parameters: $1 = '1', $2 = '1'
app_1          |   Post Load (0.4ms)  SELECT "posts".* FROM "posts" WHERE "posts"."id" = $1 LIMIT $2  [["id", 1], ["LIMIT", 1]]
app_1          |   ↳ app/controllers/posts_controller.rb:67:in `set_post'
app_1          | Redirected to http://localhost:3000/posts/1
app_1          | Completed 302 Found in 4ms (ActiveRecord: 0.8ms | Allocations: 1373)
app_1          |
app_1          |
app_1          | Started GET "/posts/1" for 172.21.0.1 at 2019-10-03 18:37:22 +0000
app_1          | Cannot render console from 172.21.0.1! Allowed networks: 127.0.0.0/127.255.255.255, ::1
pg_primary_1   | 2019-10-03 18:37:22.237 UTC [66] LOG:  statement: SELECT 1
app_1          | Processing by PostsController#show as HTML
app_1          |   Parameters: {"id"=>"1"}
pg_primary_1   | 2019-10-03 18:37:22.238 UTC [66] LOG:  execute a1: SELECT "posts".* FROM "posts" WHERE "posts"."id" = $1 LIMIT $2
pg_primary_1   | 2019-10-03 18:37:22.238 UTC [66] DETAIL:  parameters: $1 = '1', $2 = '1'
app_1          |   Post Load (0.3ms)  SELECT "posts".* FROM "posts" WHERE "posts"."id" = $1 LIMIT $2  [["id", 1], ["LIMIT", 1]]
app_1          |   ↳ app/controllers/posts_controller.rb:67:in `set_post'
app_1          |   Rendering posts/show.html.erb within layouts/application
app_1          |   Rendered posts/show.html.erb within layouts/application (Duration: 0.2ms | Allocations: 95)
app_1          | Completed 200 OK in 6ms (Views: 4.7ms | ActiveRecord: 0.3ms | Allocations: 6369)
app_1          |
app_1          |
app_1          | Started GET "/posts/1" for 172.21.0.1 at 2019-10-03 18:37:36 +0000
app_1          | Cannot render console from 172.21.0.1! Allowed networks: 127.0.0.0/127.255.255.255, ::1
pg_primary_1   | 2019-10-03 18:37:36.607 UTC [66] LOG:  statement: SELECT 1
app_1          | Processing by PostsController#show as HTML
app_1          |   Parameters: {"id"=>"1"}
pg_readonly_1  | 2019-10-03 18:37:36.609 UTC [30] LOG:  statement: SELECT 1
pg_readonly_1  | 2019-10-03 18:37:36.609 UTC [30] LOG:  execute a1: SELECT "posts".* FROM "posts" WHERE "posts"."id" = $1 LIMIT $2
pg_readonly_1  | 2019-10-03 18:37:36.609 UTC [30] DETAIL:  parameters: $1 = '1', $2 = '1'
app_1          |   Post Load (0.5ms)  SELECT "posts".* FROM "posts" WHERE "posts"."id" = $1 LIMIT $2  [["id", 1], ["LIMIT", 1]]
app_1          |   ↳ app/controllers/posts_controller.rb:67:in `set_post'
app_1          |   Rendering posts/show.html.erb within layouts/application
app_1          |   Rendered posts/show.html.erb within layouts/application (Duration: 0.2ms | Allocations: 92)
app_1          | Completed 200 OK in 8ms (Views: 5.3ms | ActiveRecord: 0.5ms | Allocations: 6356)
```
