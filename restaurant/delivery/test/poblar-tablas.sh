#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

STAGE="${STAGE:-dev}"
SUCURSAL="sucursal-001"

echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Poblando DynamoDB - Microservicio Delivery${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}\n"

# =========================================================================
# 1. VALIDAR QUE LAS TABLAS EXISTAN
# =========================================================================
echo -e "${YELLOW}Validando tablas...${NC}"

for table in "cw-usuarios-${STAGE}" "cw-pedidos-${STAGE}"; do
  if ! aws dynamodb describe-table --table-name "$table" &>/dev/null; then
    echo -e "${RED}✗ Tabla no encontrada: $table${NC}"
    exit 1
  else
    echo -e "${GREEN}✓ Tabla existe: $table${NC}"
  fi
done

echo ""

# =========================================================================
# 2. POBLAR TABLA DE USUARIOS - COCINEROS
# =========================================================================
echo -e "${BLUE}Creando COCINEROS...${NC}\n"

# Cocinero 001
if aws dynamodb put-item \
  --table-name "cw-usuarios-${STAGE}" \
  --item '{
    "user_id": {"S": "USER#cocinero-001"},
    "entity": {"S": "PROFILE"},
    "tenant_context": {"S": "TENANT#'${SUCURSAL}'"},
    "Role": {"S": "COCINERO"},
    "atributos": {"S": "{\"nombre\": \"Juan Pérez\", \"activo\": true, \"turno\": \"mañana\", \"especialidad\": \"Parrilla\"}"}
  }'; then
  echo -e "${GREEN}  ✓ Cocinero 001 (Juan Pérez)${NC}"
else
  echo -e "${RED}  ✗ Error creando cocinero 001${NC}"
  echo -e "${RED}    Verifica que la tabla 'cw-usuarios-${STAGE}' existe y tiene los atributos correctos${NC}"
fi

# Cocinero 002
if aws dynamodb put-item \
  --table-name "cw-usuarios-${STAGE}" \
  --item '{
    "user_id": {"S": "USER#cocinero-002"},
    "entity": {"S": "PROFILE"},
    "tenant_context": {"S": "TENANT#'${SUCURSAL}'"},
    "Role": {"S": "COCINERO"},
    "atributos": {"S": "{\"nombre\": \"Carlos López\", \"activo\": true, \"turno\": \"tarde\", \"especialidad\": \"Fritos\"}"}
  }'; then
  echo -e "${GREEN}  ✓ Cocinero 002 (Carlos López)${NC}"
else
  echo -e "${RED}  ✗ Error creando cocinero 002${NC}"
fi

# =========================================================================
# 3. POBLAR TABLA DE USUARIOS - DESPACHADORES
# =========================================================================
echo -e "\n${BLUE}Creando DESPACHADORES...${NC}\n"

# Despachador 001
if aws dynamodb put-item \
  --table-name "cw-usuarios-${STAGE}" \
  --item '{
    "user_id": {"S": "USER#despachador-001"},
    "entity": {"S": "PROFILE"},
    "tenant_context": {"S": "TENANT#'${SUCURSAL}'"},
    "Role": {"S": "DESPACHADOR"},
    "atributos": {"S": "{\"nombre\": \"María García\", \"activo\": true, \"turno\": \"mañana\"}"}
  }'; then
  echo -e "${GREEN}  ✓ Despachador 001 (María García)${NC}"
else
  echo -e "${RED}  ✗ Error creando despachador 001${NC}"
fi

# Despachador 002
if aws dynamodb put-item \
  --table-name "cw-usuarios-${STAGE}" \
  --item '{
    "user_id": {"S": "USER#despachador-002"},
    "entity": {"S": "PROFILE"},
    "tenant_context": {"S": "TENANT#'${SUCURSAL}'"},
    "Role": {"S": "DESPACHADOR"},
    "atributos": {"S": "{\"nombre\": \"Ana Martínez\", \"activo\": true, \"turno\": \"tarde\"}"}
  }'; then
  echo -e "${GREEN}  ✓ Despachador 002 (Ana Martínez)${NC}"
else
  echo -e "${RED}  ✗ Error creando despachador 002${NC}"
fi

# =========================================================================
# 4. POBLAR TABLA DE USUARIOS - REPARTIDORES
# =========================================================================
echo -e "\n${BLUE}Creando REPARTIDORES...${NC}\n"

# Repartidor 001
if aws dynamodb put-item \
  --table-name "cw-usuarios-${STAGE}" \
  --item '{
    "user_id": {"S": "USER#repartidor-001"},
    "entity": {"S": "PROFILE"},
    "tenant_context": {"S": "TENANT#'${SUCURSAL}'"},
    "Role": {"S": "REPARTIDOR"},
    "atributos": {"S": "{\"nombre\": \"Carlos Rodríguez\", \"activo\": true, \"vehiculo\": \"moto\", \"zona\": \"norte\"}"}
  }'; then
  echo -e "${GREEN}  ✓ Repartidor 001 (Carlos Rodríguez)${NC}"
else
  echo -e "${RED}  ✗ Error creando repartidor 001${NC}"
fi

# Repartidor 002
if aws dynamodb put-item \
  --table-name "cw-usuarios-${STAGE}" \
  --item '{
    "user_id": {"S": "USER#repartidor-002"},
    "entity": {"S": "PROFILE"},
    "tenant_context": {"S": "TENANT#'${SUCURSAL}'"},
    "Role": {"S": "REPARTIDOR"},
    "atributos": {"S": "{\"nombre\": \"Diego Fernández\", \"activo\": true, \"vehiculo\": \"bicicleta\", \"zona\": \"sur\"}"}
  }'; then
  echo -e "${GREEN}  ✓ Repartidor 002 (Diego Fernández)${NC}"
else
  echo -e "${RED}  ✗ Error creando repartidor 002${NC}"
fi

# =========================================================================
# 5. POBLAR TABLA DE PEDIDOS - METADATOS
# =========================================================================
echo -e "\n${BLUE}Creando PEDIDOS de prueba...${NC}\n"

ORDER_ID="ORD-TEST-$(date +%s)"
CUSTOMER_ID="USER#customer-test-001"
EMAIL="test@chinawok.com"

if aws dynamodb put-item \
  --table-name "cw-pedidos-${STAGE}" \
  --item '{
    "pedido_id": {"S": "Pedido#'${ORDER_ID}'"},
    "entity": {"S": "METADATA"},
    "sucursal": {"S": "'${SUCURSAL}'"},
    "Cliente": {"S": "'${CUSTOMER_ID}'"},
    "Estado": {"S": "CREADO"},
    "DesEstado": {"S": "Pedido recién creado"},
    "fecha_creacion": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
    "atributos": {"S": "{\"email\": \"'${EMAIL}'\", \"items\": 3, \"total\": 45.50}"}
  }'; then
  echo -e "${GREEN}  ✓ Pedido METADATA: ${ORDER_ID}${NC}"
else
  echo -e "${RED}  ✗ Error creando pedido${NC}"
fi

# =========================================================================
# 6. VERIFICAR ESTRUCTURA DE LA TABLA
# =========================================================================
echo -e "\n${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Verificando Esquema de Tabla${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Estructura de cw-usuarios-${STAGE}:${NC}"
aws dynamodb describe-table \
  --table-name "cw-usuarios-${STAGE}" \
  --query 'Table.[KeySchema, AttributeDefinitions, GlobalSecondaryIndexes[0].[IndexName, KeySchema]]' \
  --output table

# =========================================================================
# 7. VERIFICAR USUARIOS CREADOS POR ROL
# =========================================================================
echo -e "\n${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Verificando Usuarios Creados${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}\n"

echo -e "${GREEN}COCINEROS DISPONIBLES:${NC}\n"
aws dynamodb query \
  --table-name "cw-usuarios-${STAGE}" \
  --index-name TenantRoleIndex \
  --key-condition-expression "tenant_context = :tc AND #role = :role" \
  --expression-attribute-names '{"#role": "Role"}' \
  --expression-attribute-values '{
    ":tc": {"S": "TENANT#'${SUCURSAL}'"},
    ":role": {"S": "COCINERO"}
  }' \
  --query 'Items[*].[user_id.S, atributos.S]' \
  --output table

echo -e "\n${GREEN}DESPACHADORES DISPONIBLES:${NC}\n"
aws dynamodb query \
  --table-name "cw-usuarios-${STAGE}" \
  --index-name TenantRoleIndex \
  --key-condition-expression "tenant_context = :tc AND #role = :role" \
  --expression-attribute-names '{"#role": "Role"}' \
  --expression-attribute-values '{
    ":tc": {"S": "TENANT#'${SUCURSAL}'"},
    ":role": {"S": "DESPACHADOR"}
  }' \
  --query 'Items[*].[user_id.S, atributos.S]' \
  --output table

echo -e "\n${GREEN}REPARTIDORES DISPONIBLES:${NC}\n"
aws dynamodb query \
  --table-name "cw-usuarios-${STAGE}" \
  --index-name TenantRoleIndex \
  --key-condition-expression "tenant_context = :tc AND #role = :role" \
  --expression-attribute-names '{"#role": "Role"}' \
  --expression-attribute-values '{
    ":tc": {"S": "TENANT#'${SUCURSAL}'"},
    ":role": {"S": "REPARTIDOR"}
  }' \
  --query 'Items[*].[user_id.S, atributos.S]' \
  --output table

# =========================================================================
# 8. VERIFICAR PEDIDOS CREADOS
# =========================================================================
echo -e "\n${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Pedidos Creados${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}\n"

aws dynamodb query \
  --table-name "cw-pedidos-${STAGE}" \
  --key-condition-expression "pedido_id = :pid" \
  --expression-attribute-values '{
    ":pid": {"S": "Pedido#'${ORDER_ID}'"}
  }' \
  --query 'Items[*].[pedido_id.S, Estado.S, fecha_creacion.S]' \
  --output table

echo -e "\n${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Población completada exitosamente${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# Guardar variables de prueba para usar en test-delivery.sh
cat > "${BASH_SOURCE%/*}/test-vars.env" <<EOF
STAGE=${STAGE}
SUCURSAL=${SUCURSAL}
ORDER_ID=${ORDER_ID}
CUSTOMER_ID=${CUSTOMER_ID}
EMAIL=${EMAIL}
EOF

echo -e "\n${BLUE}Variables de prueba guardadas en: test-vars.env${NC}"