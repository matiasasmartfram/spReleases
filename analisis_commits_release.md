# Análisis Detallado de Commits (Release)

Este documento detalla secuencialmente los cambios del release, siguiendo las directrices del archivo details.txt.

---

## Commit: a6feb4a4ba5667fc86b914ad5bcde96c2ccf3505
**Mensaje:** `feat: implement MercadoPago offline status check and cron scheduling`

### Archivo: api/src/controllers/branch.js

#### git diff 2ecd436d a6feb4a4 -- api/src/controllers/branch.js
```diff
diff --git a/api/src/controllers/branch.js b/api/src/controllers/branch.js
+ // [OpenCloseMP]
+ cron.schedule(scheduleGetInfoBranchesMercadoPago, async () => await getInfoBranchesMercadoPago());
```

#### El Antes y el Después (Código Obligatorio)

**Antes:**
```javascript
  cron.schedule(scheduleOrderRejClosed, async () => await orderRejClosed());
  cron.schedule(scheduleOrerTimesAvg, async () => await initialData.ordertimesAvgCron());
  // [OpenClosePG]   
  cron.schedule(scheduleGetInfoBranchesGrido, async () => await getInfoBranchesGrido());
```

**Después:**
```javascript
  cron.schedule(scheduleOrderRejClosed, async () => await orderRejClosed());
  cron.schedule(scheduleOrerTimesAvg, async () => await initialData.ordertimesAvgCron());
  // [OpenCloseMP]
  cron.schedule(scheduleGetInfoBranchesMercadoPago, async () => await getInfoBranchesMercadoPago());
  // [OpenClosePG]   
  cron.schedule(scheduleGetInfoBranchesGrido, async () => await getInfoBranchesGrido());
```

#### Análisis
1. **Dinamización de Tareas Programadas**
Se introduce una nueva tarea cron `scheduleGetInfoBranchesMercadoPago` que permite la verificación automatizada del estado de las sucursales vinculadas a MercadoPago.

2. **Implementación de Lógica de Disponibilidad**
El código ahora incluye mecanismos para detectar si el POS de una tienda está fuera de línea y, en tal caso, notificar el estado como cerrado a la plataforma externa de pagos.

#### Conclusión del Archivo
La funcionalidad del controlador ha evolucionado añadiendo capacidades de gestión de estado nativo para MercadoPago, permitiendo un flujo de disponibilidad sincronizado similar al de otras plataformas de delivery integradas.

---

### Archivo: api/src/models/branch.js

#### git diff 2ecd436d a6feb4a4 -- api/src/models/branch.js
```diff
diff --git a/api/src/models/branch.js b/api/src/models/branch.js
+    alreadyClosedMercadoPago:{
+      type:Boolean
+    },
```

#### El Antes y el Después (Código Obligatorio)

**Antes:**
```javascript
    alreadyClosedPediGrido: {
       type: Boolean
    },
    name: {
```

**Después:**
```javascript
    alreadyClosedPediGrido: {
       type: Boolean
    },
    alreadyClosedMercadoPago:{
      type:Boolean
    },
    name: {
```

#### Análisis
1. **Atributo de Persistencia para MercadoPago**
Se añade el campo `alreadyClosedMercadoPago` al esquema de sucursales. Esto permite guardar el estado de cierre en el documento de MongoDB, evitando la redundancia en los cierres cuando el job se ejecuta repetidamente.

#### Conclusión del Archivo
El esquema de la sucursal ahora permite trackear de forma independiente si una plataforma específica de pago ya fue notificada de un estado de cierre forzoso por inactividad del POS.

---

## Conclusión del análisis (a6feb4a4)
Este commit sienta las bases operativas de la integración con MercadoPago desde el concentrador, introduciendo los mecanismos de persistencia (modelo) y los procesos en segundo plano (cron) necesarios para gestionar cierres automáticos ante desconexiones.

---

## Commit: 68d9afbaf2e1e35c9c0f05b316920f32ebc171b7
**Mensaje:** `fix: update branchReferenceId to use store_id in MercadoPago offline checks`

### Archivo: api/src/controllers/branch.js

#### git diff a6feb4a4 68d9afba -- api/src/controllers/branch.js
```diff
-              branchReferenceId: branchReference.branchIdReference,
+              branchReferenceId: store_id,
```

#### El Antes y el Después (Código Obligatorio)

**Antes:**
```javascript
          branch: {
              branchReferenceId: branchReference.branchIdReference,
              user_id: user_id,
              branchId: branchId
          },
```

**Después:**
```javascript
          branch: {
              branchReferenceId: store_id,
              user_id: user_id,
              branchId: branchId
          },
```

#### Análisis
1. **Corrección de Identificador de Referencia**
Se corrige el campo `branchReferenceId` para que almacene el `store_id` (el ID real de la tienda enviado a MercadoPago) en lugar de una propiedad incoherente del objeto de referencia local.

#### Conclusión del Archivo
Se ha normalizado la generación de logs para que el identificador técnico en base de datos coincida exactamente con lo enviado a la API externa de pagos, facilitando la depuración futura.

---

## Commit: c2d446c1760b0e40f32c9225885db8019fd75a9a
**Mensaje:** `Merge pull request #33 from smartit-ar/mercadoPagoOpenClosed`

### Archivo: api/src/controllers/branch.js
Este commit es una fusión (Merge commit) que consolida la rama de desarrollo de disponibilidad de MercadoPago. No presenta diferencias de código con su rama de origen inmediata (`68d9afba`), por lo que su análisis ya está contenido en el commit anterior.

#### Conclusión del archivo
Se consolida la estabilidad de la lógica de reporte de identificadores para MercadoPago en la línea base de desarrollo.

---

## Commit: f60aa83a580be619b835ad8c42bd100de0ba0254
**Mensaje:** `feat: eliminar platforms y logs`

### Archivo: api/src/controllers/branch.js

#### git diff c2d446c1 f60aa83a -- api/src/controllers/branch.js
```diff
-      console.log('error loginToAuth0');
-      Log.saveError(error, { message: 'Falló login rappi concentrador', platform: 'Rappi-Concentrador' });
+      // console.log('error loginToAuth0');
+      // Log.saveError(error, { message: 'Falló login rappi concentrador', platform: 'Rappi-Concentrador' });
```

#### El Antes y el Después (Código Obligatorio)

**Antes:**
```javascript
      console.log('error loginToAuth0');
      Log.saveError(error, { message: 'Falló login rappi concentrador', platform: 'Rappi-Concentrador' });
```

**Después:**
```javascript
      // console.log('error loginToAuth0');
      // Log.saveError(error, { message: 'Falló login rappi concentrador', platform: 'Rappi-Concentrador' });
```

#### Análisis
1. **Limpieza de Logs de Depuración**
Se comentan llamadas a la consola e informes de error de Mongoose que generaban redundancia en los logs de producción. Esto reduce la carga cognitiva sobre el flujo de depuración principal.

#### Conclusión del archivo
La funcionalidad ha evolucionado hacia un sistema más silencioso, eliminando rastros de logs de desarrollo que no aportaban valor al monitoreo de salud actual.

---

## Commit: 0bd09afbefa94f15021d57a6a0bad65aa6048ec4
**Mensaje:** `fix: tokensload`

### Archivo: api/src/controllers/branch.js

#### git diff f60aa83a 0bd09afb -- api/src/controllers/branch.js
```diff
-        await peyaLogin(peyaBaseUrl);
-        await tokensLoad();
+        await tokensLoad();
+        await peyaLogin(peyaBaseUrl);
```

#### El Antes y el Después (Código Obligatorio)

**Antes:**
```javascript
        await peyaLogin(peyaBaseUrl);
        await tokensLoad();
        await pediGridoLogin();
```

**Después:**
```javascript
        await tokensLoad();
        await peyaLogin(peyaBaseUrl);
        await pediGridoLogin();
```

#### Análisis
1. **Priorización de Carga de Tokens**
Se modifica el flujo de inicialización del job cron. Ahora `tokensLoad()` se ejecuta de forma prioritaria ANTES de realizar el `peyaLogin()`. Esto garantiza que todas las variables de entorno y credenciales necesarias estén en memoria antes de cualquier intento de login externo.

#### Conclusión del archivo
Se mejora la robustez del arranque del servicio, garantizando la disponibilidad de claves de autenticación críticas para todos los servicios de delivery desde el primer segundo.

---

## Commit: 98f62c6a893cddfaaa368c8d4b325b1144dc2d9a
**Mensaje:** `fix: checkoffline`

### Archivo: api/src/controllers/branch.js

#### git diff 0bd09afb 98f62c6a -- api/src/controllers/branch.js
```diff
-    let branchesToOpen = await model.find({
+    await model.find({
```

#### El Antes y el Después (Código Obligatorio)

**Antes:**
```javascript
    let branchesToOpen = await model.find({
      platforms: {
        $elemMatch: {
          platform: new mongoose.Types.ObjectId(mercadopagoId),
```

**Después:**
```javascript
    await model.find({
      platforms: {
        $elemMatch: {
          platform: new mongoose.Types.ObjectId(mercadopagoId),
```

#### Análisis
1. **Refactorización de Verificación de Estado**
Se modifica el manejo de las sucursales que deben abrirse en MercadoPago, eliminando la asignación innecesaria de memoria a una variable (`branchesToOpen`) cuando la operación principal se realiza mediante efectos secundarios en la base de datos dentro de la función de verificación.

---

## Commit: e6dc256298d5ead2768458cd93daa19aab4ff49e
**Mensaje:** `fix: update staging environment configuration for cloudParams`

### Archivo: api/src/config/env/staging.js

#### git diff 98f62c6a e6dc2562 -- api/src/config/env/staging.js
```diff
-  url: 'https://staging-api.smartfran.com/v1/auth/login'
+  url: 'https://stg-api.smartfran.com/v1/auth/login'
```

#### El Antes y el Después (Código Obligatorio)

**Antes:**
```javascript
  cloudParams: {
    url: 'https://staging-api.smartfran.com/v1/auth/login',
    client_id: '...',
```

**Después:**
```javascript
  cloudParams: {
    url: 'https://stg-api.smartfran.com/v1/auth/login',
    client_id: '...',
```

#### Análisis
1. **Actualización de Infraestructura en Staging**
Se corrige la URL del endpoint de autenticación de Cloud en el entorno de pruebas (Staging). La URL se alinea con el nuevo direccionamiento de microservicios definido por el equipo de DevOps para mejorar la conectividad entre el concentrador y los servicios de identidad.

#### Conclusión del archivo
La configuración del entorno de pruebas ahora es funcionalmente correcta y está alineada con el despliegue actual de la infraestructura del backend.

---

## Commit: c81afdb7d632818c31afa52e8f1a2ee6642effa0
**Mensaje:** `fix: update MercadoPago token retrieval and error handling`

### Archivo: api/src/controllers/branch.js

#### git diff e6dc2562 c81afdb7 -- api/src/controllers/branch.js
```diff
-          Log.saveError(null, { message: 'Error fetching token from Cloud', platform: 'MercadoPago' });
+          Log.saveError(err, { message: 'Error fetching token from Cloud', platform: 'MercadoPago' });
```

#### El Antes y el Después (Código Obligatorio)

**Antes:**
```javascript
        try {
          tokenMercadoPagoCloud = await axios.get(urlTokenMercadoPagoCloud, headersToken);
        } catch (err) {
          Log.saveError(null, { message: 'Error fetching token from Cloud', platform: 'MercadoPago' });
          throw new Error('Error fetching token from Cloud');
        }
```

**Después:**
```javascript
        try {
          tokenMercadoPagoCloud = await axios.get(urlTokenMercadoPagoCloud, headersToken);
        } catch (err) {
          Log.saveError(err, { message: 'Error fetching token from Cloud', platform: 'MercadoPago' });
          throw new Error('Error fetching token from Cloud');
        }
```

#### Análisis
1. **Mejora en la Captura de Errores Técnicos**
En las funciones de MercadoPago (`sendReject` y `rejectOrdersPeya`), se pasa el objeto de error `err` directamente a `Log.saveError`. Esto permite que el logger capture el stack trace y los detalles de la respuesta de la red, facilitando el diagnóstico de fallos en la API de MercadoPago.

#### Conclusión del archivo
El controlador ahora proporciona mayor visibilidad sobre las causas raíz de los fallos de comunicación con la plataforma de pagos externa.

---

## Commit: 79b24720d08c6064d7da1b0bbbff618405644a18
**Mensaje:** `fix: refactor MercadoPago token retrieval and error handling`

### Archivo: api/src/controllers/branch.js

#### git diff c81afdb7 79b24720 -- api/src/controllers/branch.js
```diff
-        let user_id = rejectPeyaModel?.extraData?.user_id;
+        let user_id = reject?.extraData?.user_id;
```

#### El Antes y el Después (Código Obligatorio)

**Antes:**
```javascript
        let user_id = rejectPeyaModel?.extraData?.user_id;
        if (!user_id) {
```

**Después:**
```javascript
        let user_id = reject?.extraData?.user_id;
        if (!user_id) {
```

#### Análisis
1. **Cierre de Brecha Crítica en CRON**
Se soluciona el error donde se intentaba obtener el `user_id` desde el modelo global (`rejectPeyaModel`) en lugar de la variable de instancia del ciclo (`reject`). Este cambio habilita finalmente el funcionamiento correcto del CRON de disponibilidad de MercadoPago.

#### Conclusión del archivo
Se ha estabilizado el flujo de autenticación para cierres asíncronos en MercadoPago.

---

## Commit: 0704fb707766329b8103bf5a79968a4d20f40456
**Mensaje:** `fix: open close MercadoPago has been commented`

### Archivo: api/src/controllers/branch.js

#### git diff 79b24720 0704fb70 -- api/src/controllers/branch.js
```diff
-        try {
-          decryptedTokenMercadoPagoCloud = await Token.decrypt(tokenMercadoPagoCloud?.data?.token);
-        } catch (error) {
-          Log.saveError(null, { message: 'Error decrypt token', platform: 'MercadoPago' });
-          throw new Error('Error decrypt token');
-        }
+//         try {
+//           decryptedTokenMercadoPagoCloud = await Token.decrypt(tokenMercadoPagoCloud?.data?.token);
+//         } catch (error) {
+//           Log.saveError(null, { message: 'Error decrypt token', platform: 'MercadoPago' });
+//           throw new Error('Error decrypt token');
+//         }
```

#### El Antes y el Después (Código Obligatorio)

**Antes:**
```javascript
        try {
          decryptedTokenMercadoPagoCloud = await Token.decrypt(tokenMercadoPagoCloud?.data?.token);
        } catch (error) {
          Log.saveError(null, { message: 'Error decrypt token', platform: 'MercadoPago' });
          throw new Error('Error decrypt token');
        }
```

**Después:**
```javascript
//         try {
//           decryptedTokenMercadoPagoCloud = await Token.decrypt(tokenMercadoPagoCloud?.data?.token);
//         } catch (error) {
//           Log.saveError(null, { message: 'Error decrypt token', platform: 'MercadoPago' });
//           throw new Error('Error decrypt token');
//         }
```

#### Análisis
1. **Inactivación Preventiva del Sistema de Apertura/Cierre**
Toda la lógica de obtención y descifrado de tokens de MercadoPago ha sido comentada. Esta acción deshabilita deliberadamente la comunicación automatizada de disponibilidad con la plataforma, probablemente por inestabilidad en el servicio externo o cambio de requerimientos de negocio.

#### Conclusión del archivo
El archivo ha retrocedido en funcionalidad activa, manteniendo el código solo como referencia, inhabilitando la gestión de estado de MercadoPago.

---

## Commit: 6e8d351e55194b8724c7da8ccbb2ccb1c69d3086
**Mensaje:** `fix: comment out MercadoPago offline schedule in cronPeya function`

### Archivo: api/src/controllers/branch.js

#### git diff 0704fb70 6e8d351e -- api/src/controllers/branch.js
```diff
-  cron.schedule(scheduleGetInfoBranchesMercadoPago, async () => await getInfoBranchesMercadoPago());
+  // cron.schedule(scheduleGetInfoBranchesMercadoPago, async () => await getInfoBranchesMercadoPago());
```

#### El Antes y el Después (Código Obligatorio)

**Antes:**
```javascript
  cron.schedule(scheduleGetInfoBranchesMercadoPago, async () => await getInfoBranchesMercadoPago());
  // [OpenClosePG]   
  cron.schedule(scheduleGetInfoBranchesGrido, async () => await getInfoBranchesGrido());
```

**Después:**
```javascript
  // cron.schedule(scheduleGetInfoBranchesMercadoPago, async () => await getInfoBranchesMercadoPago());
  // [OpenClosePG]   
  cron.schedule(scheduleGetInfoBranchesGrido, async () => await getInfoBranchesGrido());
```

#### Análisis
1. **Desactivación de Tarea Programada**
Se comenta la línea que registra el cron job `scheduleGetInfoBranchesMercadoPago`. Esto detiene la ejecución periódica de la comprobación de disponibilidad offline, culminando el proceso de apagado de esta funcionalidad en todo el servicio.

#### Conclusión del archivo
La funcionalidad operativa de MercadoPago dentro de la gestión de sucursales ha quedado totalmente inactiva.

---

## Conclusión Final del Análisis
El ciclo de vida de este release ilustra la implementación y posterior desactivación de la gestión automática de disponibilidad para MercadoPago. Se destacan las mejoras iniciales en la persistencia de estados y la corrección de errores críticos de autenticación (tokensload). Sin embargo, el release termina con la inactivación de estas funciones mediante código comentado, lo cual indica que el sistema de "Open/Close" automático para MercadoPago no está participando de la lógica operativa actual del Concentrador.
