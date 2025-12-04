# Red Social Elixir

Proyecto final académico para demostrar el dominio de un nuevo lenguaje de programación, funcional y concurrente: Elixir con sus frameworks: Phoenix y Ecto.
Implementa una red social completa con lógica de visibilidad compleja (Grado 2), analíticas avanzadas y relaciones entre Personas y Empresas.

## Prerrequisitos

- Elixir instalado (v1.14+)
- Phoenix instalado
- SQLite3

## Instalación (Clone & Run)

1.  **Clonar el repositorio:**
    ```bash
    git clone https://github.com/HervinY/Red-Social-ELIXIR.git
    cd Red-Social-ELIXIR
    ```

2.  **Instalar dependencias:**
    ```bash
    mix deps.get
    ```

3.  **Configurar la base de datos y sembrar datos de prueba:**
    ```bash
    mix ecto.setup
    ```
    *Este comando crea la base de datos, corre las migraciones y ejecuta `priv/repo/seeds.exs` para llenar el sistema con usuarios, empresas y relaciones.*

4.  **Iniciar el servidor:**
    ```bash
    mix phx.server
    ```

5.  **Visitar la aplicación:**
    Abre tu navegador en `http://localhost:4000`.

## Características Implementadas

### Lógica de Negocio (SocialCore)

#### Entidades
-   **Personas y Empresas**: Modeladas en la misma tabla `users` con campo discriminador `type` ("person" o "company").
-   **Publicaciones**: Con contenido de texto y timestamps.
-   **Hashtags**: Extraídos automáticamente del contenido usando expresiones regulares.
-   **Interacciones**: Like, Dislike y Repost sobre publicaciones.

#### Relaciones Avanzadas
-   **Seguir (Follow)**: `follow(user1, user2)` - Un usuario/empresa sigue a otro.
-   **Bloquear (Block)**: `block(user1, user2)` - Elimina la visibilidad mutua en feeds.
-   **Recomendar (Recommend)**: `recommend(company1, company2)` - Empresas recomiendan otras empresas.
-   **Relación Laboral (Employment)**: `employ(company, person)` - Personas trabajan en empresas.
-   **Relación Comercial (Customer)**: `add_customer(company, person)` - Personas son clientes de empresas.
-   **Amistad (Mutual Follow)**: `is_friend?(user1, user2)` - Detecta seguimiento bidireccional automáticamente.
-   **Obtener Amigos**: `get_friends(user)` - Lista todos los amigos mutuos de un usuario.

#### Motor de Visibilidad (Grado 2)
Un usuario ve las publicaciones de:
1.  **Grado 1**: Personas/empresas que sigue directamente.
2.  **Grado 2**: Personas seguidas por quienes él sigue (amigos de amigos).
3.  **Propios posts**: Siempre visibles en el feed personal.

**Filtro de Bloqueo**: Si A bloquea a B, B no aparece en el feed de A, ni A en el de B.

**Implementación**: Consultas Ecto optimizadas con subqueries para máximo rendimiento en SQLite.

#### Parseo Automático de Hashtags
Al crear una publicación, el sistema:
1.  Extrae automáticamente todos los hashtags del contenido (formato `#palabra`).
2.  Crea los hashtags en la base de datos si no existen.
3.  Asocia los hashtags con la publicación automáticamente.

Ejemplo:
```elixir
SocialCore.create_post(user, %{content: "Learning #elixir and #phoenix is amazing!"})
# Automáticamente crea y asocia los hashtags "elixir" y "phoenix"
```

### Analíticas Avanzadas

#### 1. Ranking de Empresas por Likes
`get_top_companies_by_likes()` - Top 10 empresas ordenadas por cantidad de likes en sus publicaciones.

#### 2. Hashtags en Tendencia
`get_trending_hashtags()` - Top 10 hashtags más usados en publicaciones.

#### 3. Clientes Más Fieles
`get_most_loyal_customers(company)` - Top 10 usuarios que más han dado like a publicaciones de una empresa específica.

#### 4. Ranking Completo de Empresas
`get_companies_ranking()` - Ranking con score calculado como:
```
Score = Likes - Dislikes + (Recomendaciones × 2)
```
Devuelve lista ordenada con estadísticas detalladas (likes, dislikes, recomendaciones, score).

#### 5. Estadísticas por Hashtag
`get_hashtag_stats(hashtag_name)` - Para un hashtag específico devuelve:
-   Total de publicaciones
-   Top 5 posts más populares (por engagement)
-   Bottom 5 posts menos populares

#### 6. Estadísticas de Todos los Hashtags
`get_all_hashtags_stats()` - Lista completa de todos los hashtags con sus estadísticas.

#### 7. Red de Influencia con Profundidad N
`get_influence_network(user, depth: N)` - Calcula la red de influencia de un usuario hasta N grados de separación.

Ejemplo:
```elixir
# Ver la red hasta 3 grados de profundidad
RedSocial.SocialCore.get_influence_network(user, depth: 3)

# Resultado:
# %{
#   0 => [user],                    # El usuario mismo
#   1 => [followers_grado_1],       # Quienes lo siguen
#   2 => [followers_grado_2],       # Quienes siguen a sus seguidores
#   3 => [followers_grado_3]        # Y así sucesivamente
# }
```

### Interfaz de Usuario

#### Dashboard Principal (`/`)
-   **Sección de Analíticas**:
    -   Ranking de Empresas por Likes (actualizado en tiempo real)
    -   Hashtags en Tendencia con contadores
-   **Simulador Interactivo**:
    -   Selector de usuario para simular sesión
    -   Feed personalizado con lógica Grado 2
    -   Formulario para crear publicaciones (hashtags automáticos)
    -   Botones de interacción (Like)
    -   Vista de detalles por post (autor, fecha, interacciones)

#### Gestión de Usuarios (`/users`)
-   CRUD completo para usuarios y empresas
-   Formularios de creación y edición

## Pruebas en Consola (IEx)

Puedes probar toda la lógica directamente en la consola interactiva:

```elixir
iex -S mix

# ===== Entidades y Relaciones =====

# Obtener usuarios
user1 = RedSocial.SocialCore.get_user!(1)
user2 = RedSocial.SocialCore.get_user!(2)
company = RedSocial.SocialCore.get_user!(11) # Las empresas tienen IDs mayores

# Crear relaciones
RedSocial.SocialCore.follow(user1, user2)
RedSocial.SocialCore.block(user1, user2)
RedSocial.SocialCore.employ(company, user1)
RedSocial.SocialCore.add_customer(company, user2)
RedSocial.SocialCore.recommend(company1, company2)

# Verificar amistad
RedSocial.SocialCore.is_friend?(user1, user2)
# => false (solo seguimiento unilateral)

# Hacer amigos mutuos
RedSocial.SocialCore.follow(user2, user1)
RedSocial.SocialCore.is_friend?(user1, user2)
# => true (ahora son amigos)

# Obtener lista de amigos
RedSocial.SocialCore.get_friends(user1)

# ===== Publicaciones y Hashtags =====

# Crear publicación con hashtags automáticos
{:ok, post} = RedSocial.SocialCore.create_post(user1, %{
  content: "Aprendiendo #elixir y #phoenix es increíble! #programming"
})

# Los hashtags se extraen y asocian automáticamente
post = RedSocial.Repo.preload(post, :hashtags)
post.hashtags
# => [%Hashtag{name: "elixir"}, %Hashtag{name: "phoenix"}, %Hashtag{name: "programming"}]

# Ver feed personalizado (Grado 2 con filtro de bloqueos)
RedSocial.SocialCore.get_feed_for(user1)

# ===== Interacciones =====

# Like, Dislike, Repost
RedSocial.SocialCore.like(user1, post)
RedSocial.SocialCore.dislike(user2, post)
RedSocial.SocialCore.repost(user1, post)

# ===== Analíticas =====

# Top empresas por likes
RedSocial.SocialCore.get_top_companies_by_likes()

# Hashtags trending
RedSocial.SocialCore.get_trending_hashtags()

# Clientes más fieles de una empresa
RedSocial.SocialCore.get_most_loyal_customers(company)

# Ranking completo de empresas
RedSocial.SocialCore.get_companies_ranking()

# Estadísticas de un hashtag específico
RedSocial.SocialCore.get_hashtag_stats("elixir")

# Todas las estadísticas de hashtags
RedSocial.SocialCore.get_all_hashtags_stats()

# Red de influencia hasta grado 3
RedSocial.SocialCore.get_influence_network(user1, depth: 3)

# Red de influencia hasta grado 5
RedSocial.SocialCore.get_influence_network(company, depth: 5)
```

## Estructura del Proyecto

```
lib/
├── red_social/
│   ├── accounts/
│   │   └── user.ex              # Schema de Usuarios/Empresas
│   ├── content/
│   │   ├── post.ex              # Schema de Publicaciones
│   │   ├── hashtag.ex           # Schema de Hashtags
│   │   ├── post_hashtag.ex      # Tabla de asociación
│   │   └── interaction.ex       # Schema de Interacciones
│   ├── social/
│   │   └── relationship.ex      # Schema de Relaciones polimórficas
│   ├── social_core.ex           # ⭐ LÓGICA DE NEGOCIO PRINCIPAL
│   ├── repo.ex                  # Repositorio Ecto
│   └── application.ex           # Supervisor OTP
├── red_social_web/
│   ├── live/
│   │   └── dashboard_live.ex    # LiveView del Dashboard
│   ├── controllers/
│   │   └── accounts/
│   │       ├── user_controller.ex
│   │       └── user_html.ex
│   ├── components/
│   │   ├── core_components.ex
│   │   └── layouts.ex
│   ├── router.ex
│   └── endpoint.ex
priv/
└── repo/
    ├── migrations/              # Migraciones de DB
    └── seeds.exs                # ⭐ DATOS DE PRUEBA ROBUSTOS
```

## Decisiones de Diseño

### 1. Tabla Polimórfica para Relaciones
Una sola tabla `relationships` con campo `type` permite modelar:
-   `follow`, `block`, `recommend`, `employment`, `customer`

Ventajas:
-   Consultas uniformes
-   Fácil extensión con nuevos tipos
-   Índices optimizados en `source_id` y `target_id`

### 2. Personas y Empresas en la Misma Tabla
Campo discriminador `type` en tabla `users`:
-   Simplifica queries de feeds y relaciones
-   Permite seguir tanto personas como empresas con la misma lógica
-   Pattern matching en Elixir para funciones específicas por tipo

### 3. Extracción Automática de Hashtags
Regex `~r/#(\w+)/` extrae hashtags al crear posts:
-   Crea hashtags si no existen (`on_conflict: :nothing`)
-   Normaliza a minúsculas para consistencia
-   Asociación automática en tabla intermedia

### 4. Algoritmo de Visibilidad Grado 2
Uso de subqueries de Ecto para eficiencia:
```elixir
degree_1_query # Subquery: IDs que sigo
degree_2_query # Subquery: IDs seguidos por degree_1
blocked_ids_query # Subquery: IDs bloqueados (bidireccional)

Post
|> where([p], p.author_id in subquery(degree_1_query) or ...)
|> where([p], p.author_id not in subquery(blocked_ids_query))
```

### 5. Red de Influencia Recursiva
Algoritmo recursivo con acumulador y visitados:
-   Evita ciclos infinitos (MapSet de visitados)
-   Construye mapa por grado `%{0 => [...], 1 => [...], ...}`
-   Termina cuando no hay más conexiones o se alcanza max_depth

## Tecnologías Utilizadas

-   **Elixir 1.15+**: Lenguaje funcional con concurrencia y tolerancia a fallos
-   **Phoenix 1.8**: Framework web moderno con LiveView
-   **Ecto 3.13**: ORM para consultas y migraciones
-   **SQLite**: Base de datos embebida (portabilidad)
-   **TailwindCSS**: Diseño responsivo y moderno
-   **Phoenix LiveView**: Interactividad en tiempo real sin JavaScript

## Características Académicas Destacadas

### Pattern Matching
```elixir
def employ(%User{type: "company"} = company, %User{type: "person"} = employee)
# Solo acepta empresa como primer arg y persona como segundo
```

### Composición de Queries
```elixir
degree_1_query
|> where([r], r.type == "follow")
|> subquery()
```

### Recursión con Acumuladores
```elixir
get_influence_network_recursive(user_id, max_depth, current_depth, network_acc, visited_acc)
```

### Pipelines de Transformación
```elixir
posts
|> Enum.map(fn post -> {post, calculate_engagement(post)} end)
|> Enum.sort_by(fn {_post, eng} -> eng end, :desc)
|> Enum.take(5)
```

## Autores:

**Hervin Rodriguez**
- GitHub: [@HervinY](https://github.com/HervinY)
- Proyecto Académico - Curso de Estructuras de Lenguajes

**Samuel Castro**

## Licencia

Este proyecto es de código abierto y está disponible bajo la Licencia MIT.
