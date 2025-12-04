# Red Social Elixir

Proyecto final académico para demostrar el dominio de Elixir, Phoenix y Ecto.
Implementa una red social con lógica de visibilidad compleja (Grado 2), analíticas y relaciones entre Personas y Empresas.

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
-   **Entidades**: Personas, Empresas, Publicaciones, Hashtags.
-   **Relaciones**: Seguir, Bloquear, Recomendar.
-   **Motor de Visibilidad (Grado 2)**:
    -   Un usuario ve las publicaciones de:
        1.  Personas que sigue (Grado 1).
        2.  Personas que siguen las personas que él sigue (Grado 2).
    -   **Filtro de Bloqueo**: Si A bloquea a B, B no aparece en el feed de A, ni A en el de B.

### Interfaz
-   **Dashboard Principal**:
    -   Ranking de Empresas (por Likes).
    -   Hashtags en Tendencia.
    -   **Simulador**: Permite seleccionar un usuario, ver su Feed personalizado (Grado 2) y crear publicaciones.
-   **Gestión de Usuarios**: `/users` para crear y editar usuarios.

## Pruebas en Consola (IEx)

Puedes probar la lógica directamente en la consola interactiva:

```elixir
iex -S mix

# Obtener usuarios
user1 = RedSocial.SocialCore.get_user!(1)
user2 = RedSocial.SocialCore.get_user!(2)

# Ver el feed de User 1 (incluye posts de User 2 y amigos de User 2)
RedSocial.SocialCore.get_feed_for(user1)

# Crear un post
RedSocial.SocialCore.create_post(user1, %{content: "Hola desde IEx"})

# Seguir a alguien
RedSocial.SocialCore.follow(user1, user2)
```

## Estructura del Proyecto

-   `lib/red_social/social_core.ex`: Lógica de negocio principal.
-   `lib/red_social_web/live/dashboard_live.ex`: Dashboard interactivo.
-   `priv/repo/seeds.exs`: Script de generación de datos.
