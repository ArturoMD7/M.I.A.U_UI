# M.I.A.U. UI

Un proyecto móvil desarrollado en Flutter sobre mascotas perdidas. Esta aplicación se conecta a una API REST (Backend en Django) para manejar el flujo de datos de la plataforma.

## 🛠️ Requisitos Previos

Antes de comenzar, asegúrate de tener instalado lo siguiente en tu sistema:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (Versión estable más reciente).
* Un emulador configurado (Android/iOS) o un dispositivo físico conectado.
* El backend (Django API) en ejecución de forma local o remota.

## ⚙️ Configuración del Entorno (.env)

Este proyecto utiliza el paquete `flutter_dotenv` para manejar variables de entorno y no exponer rutas o credenciales directamente en el código base.

1. En la raíz del proyecto, busca el archivo llamado `.env.example`.
2. Crea una copia de este archivo y renómbralo a `.env`.
3. Abre el nuevo archivo `.env` y asigna los valores correspondientes a tu entorno local o de producción:

```env
# URL base de tu backend (Asegúrate de no incluir un '/' al final si tu código no lo requiere)
API_URL=http://localhost:8765/api
# URL para cargar las imágenes y archivos multimedia
MEDIA_URL=http://localhost:8765
# ID del cliente
CLIENT_ID=tu_client_id_aqui