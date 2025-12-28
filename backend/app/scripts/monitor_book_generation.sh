#!/bin/bash
# Скрипт для мониторинга генерации книги до создания PDF

TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiOGRhZjFjYi05MGZiLTQwMTEtYWVkZC1mN2Q5ZjBjNmZmYmMiLCJlbWFpbCI6ImRlc3BhZC44OUBtYWlsLnJ1IiwiZXhwIjoxNzY5MDk5NTEzLCJpYXQiOjE3NjY1MDc1MTN9.Rmmh0lmF31vbOmRq0UmIxtQMEpw7nvxd1jbaTXwMfwc"
TASK_ID="f34e3026-20ef-464f-9282-22f0789b1ffa"
BASE_URL="https://storyhero.ru/api/v1"

echo "================================================================================"
echo "📚 МОНИТОРИНГ ГЕНЕРАЦИИ КНИГИ"
echo "================================================================================"
echo "Task ID: $TASK_ID"
echo "================================================================================"

MAX_WAIT=3600  # 1 час
WAIT_TIME=0
POLL_INTERVAL=5

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    RESPONSE=$(curl -s -X GET "${BASE_URL}/books/task_status/${TASK_ID}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json")
    
    STATUS=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('status', 'unknown'))" 2>/dev/null)
    PROGRESS=$(echo "$RESPONSE" | python3 -c "import sys, json; p=json.load(sys.stdin).get('progress', {}); print(f\"{p.get('stage', '')}|{p.get('current_step', 0)}|{p.get('total_steps', 0)}|{p.get('message', '')}\")" 2>/dev/null)
    
    IFS='|' read -r STAGE CURRENT_STEP TOTAL_STEPS MESSAGE <<< "$PROGRESS"
    
    printf "⏱️  [%4ds] Статус: %-10s | Этап: %-25s | Шаг: %s/%s\n" \
        "$WAIT_TIME" "$STATUS" "$STAGE" "$CURRENT_STEP" "$TOTAL_STEPS"
    
    if [ -n "$MESSAGE" ]; then
        echo "   💬 $MESSAGE"
    fi
    
    if [ "$STATUS" = "completed" ]; then
        echo ""
        echo "================================================================================"
        echo "✅ ГЕНЕРАЦИЯ КНИГИ ЗАВЕРШЕНА УСПЕШНО!"
        echo "================================================================================"
        
        PDF_URL=$(echo "$RESPONSE" | python3 -c "import sys, json; p=json.load(sys.stdin).get('progress', {}); print(p.get('pdf_url', 'N/A'))" 2>/dev/null)
        BOOK_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; p=json.load(sys.stdin).get('progress', {}); print(p.get('book_id', 'N/A'))" 2>/dev/null)
        
        if [ "$BOOK_ID" != "N/A" ]; then
            echo "📚 Book ID: $BOOK_ID"
        fi
        if [ "$PDF_URL" != "N/A" ]; then
            echo "📄 PDF URL: $PDF_URL"
        fi
        
        echo "================================================================================"
        exit 0
    elif [ "$STATUS" = "error" ]; then
        ERROR=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', 'Неизвестная ошибка'))" 2>/dev/null)
        echo ""
        echo "================================================================================"
        echo "❌ ГЕНЕРАЦИЯ ЗАВЕРШИЛАСЬ С ОШИБКОЙ"
        echo "================================================================================"
        echo "Ошибка: $ERROR"
        echo "================================================================================"
        exit 1
    fi
    
    sleep $POLL_INTERVAL
    WAIT_TIME=$((WAIT_TIME + POLL_INTERVAL))
done

echo ""
echo "⏱️  Превышено время ожидания (${MAX_WAIT}s)"
exit 1

