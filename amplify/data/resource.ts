import { type ClientSchema, a, defineData } from '@aws-amplify/backend';

const schema = a.schema({
  MaintenanceRecord: a.model({
    title: a.string().required(),
    cost: a.float().required(),
    date: a.date().required(),
    notes: a.string(),
    receiptKey: a.string(),
  })

  // --- NUEVO CANDADO DE SEGURIDAD ---
  // allow.owner() significa que AWS automáticamente le pegará una etiqueta secreta
  // a cada revisión con el ID del usuario. Nadie más podrá leerla ni modificarla.
  .authorization((allow) => [allow.owner()]),
});

export type Schema = ClientSchema<typeof schema>;

export const data = defineData({
  schema,
  authorizationModes: {
    // --- CAMBIO AL MÉTODO DE AUTENTICACIÓN ---
    // Ahora el método por defecto para conectarse exige un usuario registrado (userPool).
    defaultAuthorizationMode: 'userPool',
  },
});