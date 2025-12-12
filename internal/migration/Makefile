.PHONY: build test clean install run help

# Variablen
BINARY_NAME=migrate-db
BUILD_DIR=../../bin
SRC_DIR=./cmd/migrate-db
GO=go

# Farben für Ausgabe
GREEN=\033[0;32m
YELLOW=\033[1;33m
NC=\033[0m # No Color

help: ## Hilfe anzeigen
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║     🗄️  MySQL → SQLite Migration Tool - Makefile            ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Tool kompilieren
	@echo "$(GREEN)🔨 Kompiliere $(BINARY_NAME)...$(NC)"
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=1 $(GO) build -o $(BUILD_DIR)/$(BINARY_NAME) $(SRC_DIR)
	@echo "$(GREEN)✅ Binary erstellt: $(BUILD_DIR)/$(BINARY_NAME)$(NC)"

build-local: ## Lokal kompilieren (aktuelles Verzeichnis)
	@echo "$(GREEN)🔨 Kompiliere $(BINARY_NAME) lokal...$(NC)"
	CGO_ENABLED=1 $(GO) build -o $(BINARY_NAME) $(SRC_DIR)
	@echo "$(GREEN)✅ Binary erstellt: ./$(BINARY_NAME)$(NC)"

test: ## Tests ausführen
	@echo "$(GREEN)🧪 Führe Tests aus...$(NC)"
	$(GO) test -v ./...

test-coverage: ## Tests mit Coverage
	@echo "$(GREEN)🧪 Tests mit Coverage...$(NC)"
	$(GO) test -v -coverprofile=coverage.out ./...
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)✅ Coverage Report: coverage.html$(NC)"

clean: ## Build-Artefakte löschen
	@echo "$(YELLOW)🧹 Räume auf...$(NC)"
	rm -f $(BINARY_NAME)
	rm -f $(BUILD_DIR)/$(BINARY_NAME)
	rm -f coverage.out coverage.html
	@echo "$(GREEN)✅ Aufgeräumt$(NC)"

install: build ## Tool installieren (nach $GOPATH/bin)
	@echo "$(GREEN)📦 Installiere $(BINARY_NAME)...$(NC)"
	cp $(BUILD_DIR)/$(BINARY_NAME) $(GOPATH)/bin/
	@echo "$(GREEN)✅ Installiert nach $(GOPATH)/bin/$(BINARY_NAME)$(NC)"

run: build ## Tool mit Dry-Run starten
	@echo "$(GREEN)🚀 Starte Dry-Run...$(NC)"
	$(BUILD_DIR)/$(BINARY_NAME) --help

run-example: build ## Beispiel-Migration (Dry-Run)
	@echo "$(GREEN)🚀 Beispiel Dry-Run...$(NC)"
	@echo "$(YELLOW)⚠️  Erfordert MYSQL_DSN Umgebungsvariable$(NC)"
	$(BUILD_DIR)/$(BINARY_NAME) --source "$${MYSQL_DSN}" --target "./test.db" --dry-run --verbose

lint: ## Code linting
	@echo "$(GREEN)🔍 Linting...$(NC)"
	golangci-lint run ./...

fmt: ## Code formatieren
	@echo "$(GREEN)🎨 Formatiere Code...$(NC)"
	$(GO) fmt ./...

deps: ## Abhängigkeiten aktualisieren
	@echo "$(GREEN)📦 Aktualisiere Abhängigkeiten...$(NC)"
	$(GO) mod tidy

# Migrations-Beispiele
migrate-dry: build ## Dry-Run Migration
	@echo "$(GREEN)🔍 Dry-Run Migration...$(NC)"
	$(BUILD_DIR)/$(BINARY_NAME) \
		--source "$${MYSQL_DSN:-root:@tcp(localhost:3306)/RentalCore}" \
		--target "./rentalcore.db" \
		--dry-run \
		--verbose

migrate-real: build ## Echte Migration (Vorsicht!)
	@echo "$(YELLOW)⚠️  ACHTUNG: Echte Migration!$(NC)"
	@echo "$(YELLOW)   Drücken Sie CTRL+C innerhalb von 5 Sekunden zum Abbrechen...$(NC)"
	@sleep 5
	$(BUILD_DIR)/$(BINARY_NAME) \
		--source "$${MYSQL_DSN:-root:@tcp(localhost:3306)/RentalCore}" \
		--target "./rentalcore.db" \
		--validate

export-order: build ## Tabellen-Reihenfolge exportieren
	@echo "$(GREEN)📋 Exportiere Tabellen-Reihenfolge...$(NC)"
	$(BUILD_DIR)/$(BINARY_NAME) \
		--source "$${MYSQL_DSN:-root:@tcp(localhost:3306)/RentalCore}" \
		--export-order "./table_order_live.json" \
		--dry-run
