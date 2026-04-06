# Tarea: Corregir el descifrado del Token de MercadoPago y Mejora de Logs

## Objetivo principal
Resolver los errores frecuentes de "Error decrypt token" en `api/src/controllers/branch.js` y estandarizar el reporte de errores para todas las operaciones de MercadoPago con el fin de facilitar el mantenimiento.

## Archivo para modificar
- `api/src/controllers/branch.js`

## Análisis de las Causas Raíz
1. **Error de Alcance (Scope) en `rejectOrdersPeya`**: El código usa el modelo global `rejectPeyaModel` en lugar de la instancia local `reject` dentro del ciclo `for`. Esto hace que el `user_id` sea `undefined` y falle el proceso.
2. **Error Lógico en `sendReject`**: Se usa `model.name` que devuelve la cadena rígida `"branch"` (nombre del esquema de Mongoose), en lugar del nombre real de la cadena o sucursal necesaria para buscar el "tenant".
3. **Falta de Validación de Campo**: El código intenta descifrar `tokenMercadoPagoCloud?.data?.token` sin comprobar si la propiedad `.token` existe realmente, lo que lanza errores de "Encrypted text is undefined".
4. **Contexto Insuficiente en Logs**: Se usa `Log.saveError(null, ...)` con mensajes genéricos que no permiten identificar a qué sucursal u orden pertenece el fallo.

---

## Instrucciones Paso a Paso

### 1. Corregir `rejectOrdersPeya` (Case 8 - MercadoPago)
- **Localizar**: Aproximadamente en la línea 3036.
- **Cambio**: Reemplazar `let user_id = rejectPeyaModel?.extraData?.user_id;` por `let user_id = reject?.extraData?.user_id;`.
- **Validación**: Asegurar que tanto `tokenAPICloud` como `user_id` tengan su propia validación con un `Log.saveError` detallado que incluya `{ order: { id: reject.orderId } }`.

### 2. Corregir `sendReject` (Case 8 - MercadoPago)
- **Localizar**: Aproximadamente en la línea 2690.
- **Cambio**: Implementar una búsqueda real de la cadena/sucursal para hallar el nombre correcto del "tenant".
- **Lógica sugerida**: 
  ```javascript
  const branchData = await model.findOne({ branchId: orderInfo.branchId });
  const chainModel = require('../models/chain');
  const chainObj = await chainModel.findById(branchData?.chain);
  let tenant = tenants.find(t => t.name === chainObj?.chain?.trim().toLowerCase());
  ```

### 3. Implementar Validación de Campo de Token
- **Requisito**: Antes de invocar `Token.decrypt()`, verificar explícitamente si el campo del token existe en la respuesta.
- **Registro de Logs**: Si falta, guardar en el log el contenido completo de `tokenMercadoPagoCloud.data` para diagnosticar qué está devolviendo la API de Cloud.

### 4. Formato de Logs Estandarizado (Estructura en Español)
Cada llamada a `Log.saveError` en los bloques de MercadoPago debe seguir este patrón:
```javascript
Log.saveError(error, {
  message: 'Error de comunicación de plataforma: MercadoPago [ACCIÓN] [TIPO_ERROR] [ID_ORDEN]',
  action: '[sendReject | confirmOrder | openClose]',
  platformId: 8,
  order: {
    id: orderInfo.order.id, // o reject.orderId según la función
    branchId: orderInfo.branchId
  },
  data: { ...contextoExtra } // user_id, respuestas de API, etc.
});
```

---

## Notas Técnicas para el Descifrado
La utilidad `Token.decrypt` espera un "string" no vacío. Si se le pasa `undefined` o `null`, lanzará una excepción. Se recomienda:
```javascript
const rawToken = response?.data?.token;
if (!rawToken) throw new Error("Falta el campo token en la respuesta de Cloud");
const decrypted = await Token.decrypt(rawToken);
```
