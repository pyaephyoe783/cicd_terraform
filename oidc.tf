resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com" //github ကလာတာတွေကိုလက်ခံမယ်
  client_id_list  = ["sts.amazonaws.com"] // amazon ရဲ့ security token service အတွက်လာကြတာ

  # GitHub Actions ရဲ့ လက်ရှိ OIDC Thumbprints
  thumbprint_list = [
   "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a21d2931987e279f0f9810b74100693a1f87",
    "d89e3bd43d5d909b47a1897730d54102b8001745"
  ]
}  // OIDC Provider မှတ်ပုံတင်ခြင်း ( github ကလာတယ့် ဧည့်သည်တွေကို ကျွန်တော်တို့လက်ခံမယ်)

resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity" //WebToken နဲ့လာတယ့်သူတွေ
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn // gituhub ကလာတယ့်သူတွေ
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" : "repo:pyaephyoe783/cicd_terraform:*"//ဒီ repo ကလာတယ့်သူတွေ
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"//ဒီဧည့်သည်ကဒ်က sts:amazon အတွက်ထုတ်ထားတာလားစစ်ဆေးတာ
          }
        }
      }
    ]
  })
} // အခန်းသော့ထုတ်ပေးမယ့်စည်းကမ်းချက်သက်မှတ်ခြင်း  ( Trust Policy )




resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" //အပေါ်က role ကလာတယ့်သူတွေက admin access ရမယ်လို့ပြောထားတာ
}  // အခန်းသော့ခွင့်ပြုချက် ( Permission Policy )

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_role.arn
  description = "The ARN of the github actions Iam Role For OIDC"
}