#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar variables de prueba
if [[ -f "${SCRIPT_DIR}/test-vars.env" ]]; then
  source "${SCRIPT_DIR}/test-vars.env"
else
  echo -e "${RED}✗ Falta archivo test-vars.env. Ejecuta poblar-tablas.sh primero${NC}"
  exit 1
fi

STAGE="${STAGE:-dev}"
SUCURSAL="${SUCURSAL:-sucursal-001}"
CUSTOMER_ID="${CUSTOMER_ID:-USER#customer-test-001}"
EMAIL="${EMAIL:-test@chinawok.com}"
ORDER_ID="${ORDER_ID:-ORD-TEST-$(date +%s)}"

# =========================================================================
# FUNCIONES AUXILIARES
# =========================================================================

log_test() {
  local test_name=$1
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}TEST: ${test_name}${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

get_event_bus_name() {
  # Obtener el nombre del Event Bus desde CloudFormation
  local bus_name=$(aws cloudformation describe-stacks \
    --stack-name "cw-infra-shared-${STAGE}" \
    --query 'Stacks[0].Outputs[?OutputKey==`BusNameExport`].OutputValue' \
    --output text 2>/dev/null)
  
  if [[ -z "$bus_name" ]] || [[ "$bus_name" == "None" ]]; then
    echo "default"
  else
    echo "$bus_name"
  fi
}

publish_event() {
  local detail_type=$1
  local event_payload=$2
  local source="${3:-payment.service}"
  
  echo -e "${YELLOW}Publicando evento: ${detail_type}${NC}"
  
  local EVENT_BUS=$(get_event_bus_name)
  echo -e "${BLUE}  Event Bus: ${EVENT_BUS}${NC}"

  local clean_payload=$(echo "$event_payload" | jq -c '.')
  
  # Crear el JSON del evento con formato correcto
  local entries=$(cat <<EOF
[
  {
    "Source": "${source}",
    "DetailType": "${detail_type}",
    "Detail": $(echo "$clean_payload" | jq -R .),
    "EventBusName": "${EVENT_BUS}"
  }
]
EOF
)
  
  echo -e "${BLUE}  Payload:${NC}"
  echo "$entries" | jq '.' || true
  
  # Publicar el evento y capturar la respuesta completa
  local response=$(aws events put-events --entries "$entries" 2>&1)
  local exit_code=$?
  
  if [[ $exit_code -eq 0 ]]; then
    echo "$response" > /tmp/event-response.json
    
    # Verificar si hay errores en la respuesta
    local failed_count=$(jq '.FailedEntryCount' /tmp/event-response.json 2>/dev/null || echo "0")
    
    if [[ "$failed_count" == "0" ]]; then
      echo -e "${GREEN}✓ Evento publicado exitosamente${NC}"
      local entry_id=$(jq -r '.Entries[0].EventId' /tmp/event-response.json 2>/dev/null || echo "unknown")
      echo -e "${BLUE}  Event ID: ${entry_id}${NC}"
    else
      echo -e "${RED}✗ Entradas fallidas: ${failed_count}${NC}"
      echo -e "${RED}Detalles:${NC}"
      jq '.Entries[] | select(.ErrorCode != null)' /tmp/event-response.json 2>/dev/null || echo "$response"
    fi
  else
    echo -e "${RED}✗ Error publicando evento${NC}"
    echo -e "${RED}Error details:${NC}"
    echo "$response"
  fi
}

wait_for_execution() {
  local execution_arn=$1
  local max_wait=30
  local elapsed=0
  
  echo -e "${YELLOW}Esperando finalización de la ejecución...${NC}"
  
  while [[ $elapsed -lt $max_wait ]]; do
    local status=$(aws stepfunctions describe-execution \
      --execution-arn "$execution_arn" \
      --query 'status' \
      --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [[ "$status" == "SUCCEEDED" ]]; then
      echo -e "${GREEN}✓ Ejecución completada exitosamente${NC}"
      return 0
    elif [[ "$status" == "FAILED" ]]; then
      echo -e "${RED}✗ Ejecución falló${NC}"
      return 1
    fi
    
    sleep 2
    elapsed=$((elapsed + 2))
  done
  
  echo -e "${YELLOW}⚠ Tiempo de espera agotado${NC}"
  return 1
}

# =========================================================================
# VERIFICAR PRE-REQUISITOS
# =========================================================================
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Verificando Pre-requisitos${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}\n"

EVENT_BUS=$(get_event_bus_name)
echo -e "${YELLOW}Event Bus detectado: ${EVENT_BUS}${NC}"

# Verificar que la StateMachine existe (ahora busca ms-delivery-dev)
STATEMACHINE_ARN=$(aws stepfunctions list-state-machines \
  --query "stateMachines[?contains(name, 'ms-delivery')].stateMachineArn" \
  --output text 2>/dev/null || echo "")

if [[ -z "$STATEMACHINE_ARN" ]]; then
  echo -e "${RED}✗ No se encontró StateMachine ms-delivery${NC}"
  echo -e "${YELLOW}StateMachines disponibles:${NC}"
  aws stepfunctions list-state-machines --query "stateMachines[*].[name, type]" --output table
  echo -e "${YELLOW}Despliega el microservicio antes: cd ../.. && npm run deploy:restaurant:delivery${NC}"
  exit 1
else
  echo -e "${GREEN}✓ StateMachine encontrada: ${STATEMACHINE_ARN}${NC}"
fi

# =========================================================================
# TEST 1: PAGO CONFIRMADO → EN PREPARACIÓN
# =========================================================================
log_test "PagoConfirmado → EnPreparación"

CORRELATION_ID="test-$(date +%s%N)"

EVENTO_PAGO=$(cat <<EOF
{
  "orderId": "${ORDER_ID}",
  "sucursalId": "${SUCURSAL}",
  "customerId": "${CUSTOMER_ID}",
  "customerEmail": "${EMAIL}",
  "correlationId": "${CORRELATION_ID}",
  "amount": 45.50,
  "paymentMethod": "credit_card"
}
EOF
)

publish_event "PagoConfirmado" "$EVENTO_PAGO" "payment.service"

sleep 1

# =========================================================================
# TEST 2: COMIDA PREPARADA → EN DESPACHO
# =========================================================================
log_test "ComidaPreparada → EnDespacho"

EVENTO_COMIDA=$(cat <<EOF
{
  "orderId": "${ORDER_ID}",
  "sucursalId": "${SUCURSAL}",
  "customerId": "${CUSTOMER_ID}",
  "customerEmail": "${EMAIL}",
  "correlationId": "${CORRELATION_ID}",
  "cocineroId": "USER#cocinero-001"
}
EOF
)

publish_event "ComidaPreparada" "$EVENTO_COMIDA" "kitchen.service"

sleep 1

# =========================================================================
# TEST 3: DESPACHADO → EN CAMINO
# =========================================================================
log_test "Despachado → EnCamino"

EVENTO_DESPACHO=$(cat <<EOF
{
  "orderId": "${ORDER_ID}",
  "sucursalId": "${SUCURSAL}",
  "customerId": "${CUSTOMER_ID}",
  "customerEmail": "${EMAIL}",
  "correlationId": "${CORRELATION_ID}",
  "despachadorId": "USER#despachador-001"
}
EOF
)

publish_event "Despachado" "$EVENTO_DESPACHO" "packing.service"

sleep 1

# =========================================================================
# TEST 4: ENTREGADO → COMPLETADO
# =========================================================================
log_test "Entregado → Completado"

EVENTO_ENTREGA=$(cat <<EOF
{
  "orderId": "${ORDER_ID}",
  "sucursalId": "${SUCURSAL}",
  "customerId": "${CUSTOMER_ID}",
  "customerEmail": "${EMAIL}",
  "correlationId": "${CORRELATION_ID}",
  "confirmationCode": "CONFIRM-$(date +%s)",
  "deliveryTimestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

publish_event "Entregado" "$EVENTO_ENTREGA" "driver.service"

# =========================================================================
# RESUMEN Y VERIFICACIÓN
# =========================================================================
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Resumen de Pruebas${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}\n"

echo -e "${GREEN}Pedido de Prueba:${NC} ${ORDER_ID}"
echo -e "${GREEN}Cliente:${NC} ${CUSTOMER_ID}"
echo -e "${GREEN}Email:${NC} ${EMAIL}"
echo -e "${GREEN}Correlation ID:${NC} ${CORRELATION_ID}"
echo -e "${GREEN}Event Bus:${NC} ${EVENT_BUS}"
echo -e "${GREEN}StateMachine:${NC} ${STATEMACHINE_ARN}"

echo -e "\n${YELLOW}Próximos pasos:${NC}"
echo -e "1. Revisar logs en CloudWatch:"
echo -e "   ${BLUE}aws logs tail /aws/lambda/delivery-ms-${STAGE}-sendEmail --follow${NC}"
echo -e "2. Ver ejecuciones de Step Function:"
echo -e "   ${BLUE}aws stepfunctions list-executions --state-machine-arn '${STATEMACHINE_ARN}' --max-results 5${NC}"
echo -e "3. Revisar eventos en EventBridge:"
echo -e "   ${BLUE}aws events list-rules --event-bus-name ${EVENT_BUS}${NC}"
echo -e "4. Ver las reglas EventBridge que triggean la StateMachine:"
echo -e "   ${BLUE}aws events list-targets-by-rule --rule ms-delivery-${STAGE}-PagoConfirmado --event-bus-name ${EVENT_BUS}${NC}"

echo -e "\n${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Pruebas completadas${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"