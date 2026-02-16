# AWS Networking — Troubleshooting (Part 1)

Your teammate was asked to deploy an Nginx application on an EC2 instance. Two days
later, he contacts you asking if you'd help him deploy the application. During the deployment,
your colleague noticed he couldn't communicate with the EC2 instance. Your task is to
troubleshoot the issue that prevents communication with the instance via its public IP address.


---

## 1. Purpose of the Task

**Find and diagnose the problem:**

> **No communication with the EC2 instance via its public IP address.**

**After the fix:**
- The default **Nginx** page is accessible via **HTTP (port 80)**.
- Administrator Connection with EC2 should be **secured**.
- The instance can **download packages from the Internet** according to user data.

---

## 2. Rules and Restrictions

- **Allowed:** Modifications in **Terraform**.
- **Prohibited:**
  - Opening **`0.0.0.0/0`** without reflection/justification.
  - Changing the **VPC CIDR**.
  - Deleting the **entire stack**.

---

## 3. Best Practices and Tips

- https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html  
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-best-practices.html  
- https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html

---

## 4. Additional Requirements

Consider and propose Terraform/infrastructure modifications that improve the current solution.  
Focus on the benefits for **cost**, **automation**, **optimization**, and **maintenance** from a DevOps perspective.  
Your goal is to convince your teammate why changing the current approach is worthwhile.

---

## Additional Challenges

1. **Infrastructure as Code** – Implement your upgraded solution in Terraform (code changes included).
2. **Diagram** – Prepare a diagram of the **current** implemented infrastructure to visualize the concept.

> The above are required to complete the task. If you have time and motivation, you may add more functionality and best practices.

---

**Good luck!**
