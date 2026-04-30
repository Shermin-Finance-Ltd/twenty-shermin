resource "aws_s3_bucket" "attachments" {
  bucket = "${local.name}-attachments-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name    = "${local.name}-attachments"
    Purpose = "Twenty CRM file attachments"
  }
}

resource "aws_s3_bucket_public_access_block" "attachments" {
  bucket                  = aws_s3_bucket.attachments.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  # Tiered retention aligned to FCA rules (CONC requires 6 years for credit
  # records — we use 7 as a safety margin, then keep them forever in cheaper
  # storage rather than ever permanently deleting anything).
  #
  # Current versions:
  #   - 0–90 days:  S3 Standard            (active access, fast)
  #   - 90 d–7 yr:  Glacier Instant Retrieval (instant ms retrieval, ~30% cheaper)
  #   - 7 yr+:      Glacier Deep Archive   (12h retrieval, ~95% cheaper than Standard)
  # Non-current versions (overwritten / replaced files):
  #   - 0–30 days:  Standard               (recent overwrites are easiest to hit)
  #   - 30 d–7 yr:  Glacier Instant Retrieval
  #   - 7 yr+:      Glacier Deep Archive
  # Nothing is ever expired or deleted.

  rule {
    id     = "tiered-retention-current-versions"
    status = "Enabled"
    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 2555 # ~7 years
      storage_class = "DEEP_ARCHIVE"
    }
  }

  rule {
    id     = "tiered-retention-noncurrent-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER_IR"
    }

    noncurrent_version_transition {
      noncurrent_days = 2555 # ~7 years
      storage_class   = "DEEP_ARCHIVE"
    }

    # No noncurrent_version_expiration — files are never deleted.
  }

  # Clean up incomplete multipart uploads (purely housekeeping, not retention).
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
