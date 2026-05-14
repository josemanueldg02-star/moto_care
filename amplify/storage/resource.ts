import { defineStorage } from '@aws-amplify/backend';

export const storage = defineStorage({
    name: 'motoFacturas',
    access: (allow) => ({
        // Carpeta segura 'FACTURAS'
        // Solo los usuarios que haya iniciado sesión podrán leer, escribir o borrar fotos ahí.
        'facturas/*': [
            allow.authenticated.to(['read', 'write', 'delete'])
        ]
    })
});