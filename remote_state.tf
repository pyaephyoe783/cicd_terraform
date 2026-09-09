resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-tf-state-bucket-ye-yint-2026"
  force_destroy = true

  tags = {
    Name = "Terraform-State-Bucket"
  }

#   lifecycle {
#     prevent_destroy = true # Destroy ခေါက်ရင် Bucket ပျက်မသွားအောင် ကာကွယ်ပေးပါသည်
#   }
}

resource "aws_s3_bucket_versioning" "versioning"{
    bucket = aws_s3_bucket.terraform_state.id
    versioning_configuration {
        status = "Enabled"
    }
}
