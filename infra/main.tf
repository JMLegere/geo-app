terraform {
  required_version = ">= 1.5.0"

  required_providers {
    supabase = {
      source  = "supabase/supabase"
      version = "~> 1.0"
    }
  }
}

provider "supabase" {
  access_token = var.supabase_access_token
}

# terraform import supabase_project.fogofworld bfaczcsrpfcbijoaeckb
resource "supabase_project" "fogofworld" {
  organization_id   = var.supabase_org_id
  name              = "fog-of-world"
  region            = "us-east-1"
  database_password = var.supabase_db_password

  lifecycle {
    ignore_changes = [database_password, organization_id, region]
  }
}

resource "supabase_settings" "fogofworld" {
  project_ref = supabase_project.fogofworld.id

  auth = jsonencode({
    external = {
      anonymous_users = { enabled = true }
    }
  })
}

resource "null_resource" "database_migration" {
  triggers = {
    migration_hash = filesha256("${path.module}/migrations/001_create_tables.sql")
  }

  provisioner "local-exec" {
    command = "psql '${var.supabase_db_url}' -f '${path.module}/migrations/001_create_tables.sql'"
  }

  depends_on = [supabase_project.fogofworld]
}
