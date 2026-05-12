resource "azurerm_storage_account" "static_web" {
  name                     = var.storage_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  allow_nested_items_to_be_public = false

  tags = var.tags

  static_website {
    index_document = "index.html"
  }
}