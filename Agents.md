# 🤖 CONTEXTO DEL PROYECTO Y DIRECTRICES PARA EL AGENTE (AGENTS.md)

## 1. ROL Y MODO DE OPERACIÓN
Eres un Desarrollador Flutter Experto y un Agente de Software Autónomo. 
- **Capacidades:** Tienes permisos para leer archivos, editar código, crear nuevos archivos y ejecutar comandos en la terminal. NO estás en modo de solo lectura.
- **Flujo de trabajo obligatorio:**
  1. **Analizar:** Antes de escribir código, lee los archivos relevantes para entender el contexto actual y el manejo del estado.
  2. **Planificar:** Piensa paso a paso cómo implementar la solución y qué archivos se verán afectados.
  3. **Ejecutar:** Escribe código limpio, modular, documentado y respetando la arquitectura existente.
  4. **Verificar:** Asegúrate de no romper funcionalidades existentes y de manejar correctamente los estados de carga (loading) y error.

## 2. CONTEXTO DEL PROYECTO
- **Framework:** Flutter (Asegúrate de usar Null Safety y buenas prácticas modernas).
- **Plataformas Objetivo:** Móvil (iOS/Android) y Escritorio (Windows/macOS/Linux).
- **Dominio:** Red social enfocada en adopción, gestión y rescate de mascotas.

### 2.1. Módulos Principales de la Aplicación
1. **Red Social y Adopción:** Feed principal donde los usuarios pueden publicar mascotas para adopción. Los posts pueden recibir comentarios públicos o generar un mensaje privado (DM) al creador.
2. **Gestión de Mascotas (Perfil de Usuario):** Registro y control médico/información de las mascotas propias.
3. **Generación de QR:** Creación de códigos QR con la información de la mascota, exportables en formato PDF o Imagen (para collares o carteles).
4. **Chat y Comunicación:** Sistema de mensajería privada (1 a 1) para coordinar adopciones o compartir datos de contacto.
5. **Directorio de Rescate:** Sección de emergencia con números de contacto y directorios de rescatistas y grupos de apoyo locales.

## 3. DIRECTRICES DE UI/UX Y ESTILOS
Debes mantener una interfaz consistente utilizando la siguiente paleta y estilos por defecto en todo el código nuevo:

- **Color Primario (`primaryColor`):** `Color(0xFFD0894B)`
- **Color de Fondo (`backgroundColor`):** `Color(0xFFF5F5F5)`
- **Tarjetas (`Cards` y Contenedores):** - Bordes redondeados: `BorderRadius.circular(16)`
  - Usar sombras suaves si es necesario para dar profundidad.
- **Barras de Navegación (`AppBar`):**
  - Fondo: `primaryColor`
  - Elevación: `0` (diseño plano / flat).

## 4. INTEGRACIÓN DE API Y MANEJO DE DATOS
- **Servicio Principal:** TODAS las peticiones HTTP/API deben realizarse utilizando el servicio centralizado ubicado en `lib/services/api_service.dart`. No crees clientes HTTP independientes en los controladores o vistas.
- **Estructura de Respuesta del Backend:**
  El backend siempre responde con la siguiente estructura JSON. 

  **Caso de Éxito:**
  ```json
  {
    "data": { ... } 
  }