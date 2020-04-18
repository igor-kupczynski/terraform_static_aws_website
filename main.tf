# --- Inputs ---------------------------------------------------------------
variable region {
  description = "AWS region to use"
  default     = "us-east-1"
}

variable domain {
  description = "Domain under which the website is served"
}

variable index_document {
  description = "Document to serve if the root of the domain is requested"
  default     = "index.html"
}

variable error_404_document {
  description = "Document to serve if requested object doesn't exist in the bucket"
}

variable ssl_certificate_arn {
  default     = ""
  description = "ARN of the certificate covering the domain plus subdomains under which the website is accessed, e.g. domain.com and *.domain.com"
}

variable redirect_subdomain {
  default     = ""
  description = "Redirect redirect_subdomain.domain --> domain. If not set do not redirect."
}

variable invalidate_cloud_front_on_s3_update {
  default     = true
  description = "Setup lambda to invalidate CDN on S3 updates"
}

variable default_cdn_ttl {
  default     = 5184000
  description = "TTL of the cached objects, defaults to 60 days"
}

# --- Outputs --------------------------------------------------------------
output "s3_url" {
  value = aws_s3_bucket.storage_bucket.website_endpoint
}

output "s3_subdomain_url" {
  value = aws_s3_bucket.redirect_subdomain[0].bucket
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.cdn[0].domain_name
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cdn[0].domain_name
}

output "cloudfront_hosted_zone_id" {
  value = aws_cloudfront_distribution.cdn[0].hosted_zone_id
}

output "cloudfront_subdomain_redirect_url" {
  value = aws_cloudfront_distribution.cdn_redirect_subdomain[0].domain_name
}

output "cloudfront_subdomain_redirect_domain_name" {
  value = aws_cloudfront_distribution.cdn_redirect_subdomain[0].domain_name
}

output "cloudfront_subdomain_redirect_hosted_zone_id" {
  value = aws_cloudfront_distribution.cdn_redirect_subdomain[0].hosted_zone_id
}

# --- Resource configuraiton -----------------------------------------------

# Bucket to store the static website
resource "aws_s3_bucket" "storage_bucket" {
  bucket = var.domain
  acl    = "public-read"

  website {
    index_document = var.index_document
    error_document = var.error_404_document
  }
}

resource "aws_s3_bucket_policy" "storage_bucket" {
  bucket = aws_s3_bucket.storage_bucket.id

  policy = <<EOF
{
  "Version":"2012-10-17",
  "Statement":[{
	"Sid":"PublicReadGetObject",
        "Effect":"Allow",
	  "Principal": "*",
      "Action":["s3:GetObject"],
      "Resource":["arn:aws:s3:::${var.domain}/*"
      ]
    }
  ]
}
EOF
}

# Bucket to redirect subdomain --> non-subdomain
resource "aws_s3_bucket" "redirect_subdomain" {
  count = var.redirect_subdomain != "" ? 1 : 0

  bucket = "${var.redirect_subdomain}.${var.domain}"
  acl    = "public-read"

  website {
    redirect_all_requests_to = var.domain
  }
}

# Cloudfront in front of the main site
resource "aws_cloudfront_distribution" "cdn" {
  count = var.ssl_certificate_arn != "" ? 1 : 0

  origin {
    domain_name = aws_s3_bucket.storage_bucket.website_endpoint
    origin_id   = "origin-${var.domain}"

    # Secret sauce required for the aws api to accept cdn pointing to s3 website endpoint
    # http://stackoverflow.com/questions/40095803/how-do-you-create-an-aws-cloudfront-distribution-that-points-to-an-s3-static-ho#40096056
    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1"]
    }
  }

  enabled = true

  default_root_object = var.index_document

  custom_error_response {
    error_code            = "404"
    error_caching_min_ttl = var.default_cdn_ttl
    response_code         = "404"
    response_page_path    = "/${var.error_404_document}"
  }

  aliases = [var.domain]

  price_class = "PriceClass_100"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-${var.domain}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    default_ttl            = var.default_cdn_ttl
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.ssl_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

# Cloudfront in front of the subdomain redirect bucket
resource "aws_cloudfront_distribution" "cdn_redirect_subdomain" {
  count = (var.ssl_certificate_arn != "" ? 1 : 0) * (var.redirect_subdomain != "" ? 1 : 0)

  origin {
    domain_name = aws_s3_bucket.redirect_subdomain[count.index].website_endpoint
    origin_id   = "origin-${var.redirect_subdomain}.${var.domain}"

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1"]
    }
  }

  enabled = true

  aliases = ["igor.${var.domain}"]

  price_class = "PriceClass_100"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-${var.redirect_subdomain}.${var.domain}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    default_ttl            = var.default_cdn_ttl
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.ssl_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}
