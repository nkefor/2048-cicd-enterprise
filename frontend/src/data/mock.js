// Portfolio mock data for Hansen Nkefor - DevOps Engineer

export const personalInfo = {
  name: "Hansen Nkefor",
  title: "DevOps Engineer | Cloud Architect | Multi-Cloud Infrastructure Specialist",
  location: "Atlanta, GA",
  email: "hansen.nkefor@example.com",
  linkedin: "https://linkedin.com/in/hansennkefor",
  tagline: "Building enterprise cloud systems that balance reliability, security, and cost efficiency."
};

export const aboutMe = {
  intro: "I'm a DevOps Engineer with 9+ years building enterprise cloud systems that balance reliability, security, and cost efficiency. I specialize in turning expensive, fragile infrastructure into automated, compliant, cost-optimized platforms.",
  highlight: "Most recently, I led a Fortune 500 healthcare organization through a 500-workload migration to AWS—zero downtime, 25% cost reduction, full HIPAA compliance.",
  philosophy: "Infrastructure should be invisible to developers, auditable to compliance teams, and sustainable for finance departments."
};

export const services = [
  {
    id: 1,
    title: "Cloud Infrastructure & Migration",
    items: [
      "Design and implement multi-cloud architectures (AWS, Azure) supporting thousands of users",
      "Lead enterprise cloud migrations with zero downtime and improved performance",
      "Build hybrid cloud solutions connecting on-premise systems with cloud platforms",
      "Reduce infrastructure costs 30-70% through systematic optimization and FinOps practices"
    ]
  },
  {
    id: 2,
    title: "DevOps & Automation",
    items: [
      "Build CI/CD pipelines reducing deployment time from days to minutes",
      "Automate infrastructure provisioning with Terraform, reducing setup from days to hours",
      "Implement GitOps workflows enabling developers to deploy safely and independently",
      "Create self-service platforms that eliminate bottlenecks and ticket queues"
    ]
  },
  {
    id: 3,
    title: "Security & Compliance",
    items: [
      "Implement compliance frameworks (SOC 2, HIPAA, GDPR) passing audits with zero critical findings",
      "Harden Kubernetes clusters and cloud infrastructure reducing security incidents 30%",
      "Automate security scanning in CI/CD pipelines catching vulnerabilities before production",
      "Build security monitoring and incident response systems"
    ]
  },
  {
    id: 4,
    title: "Reliability Engineering",
    items: [
      "Maintain 99.9% uptime across production environments through multi-region architecture",
      "Reduce mean time to recovery (MTTR) from 45 minutes to 12 minutes through automation",
      "Implement SLIs, SLOs, and error budgets balancing feature velocity with reliability",
      "Design self-healing systems and automated failover mechanisms"
    ]
  }
];

export const technicalSkills = {
  "Cloud Platforms": {
    AWS: ["EC2", "EKS", "Lambda", "S3", "RDS", "VPC", "IAM", "CloudFormation", "Cost Explorer", "GuardDuty", "Security Hub"],
    Azure: ["Virtual Machines", "AKS", "App Services", "Functions", "Storage", "Virtual Networks", "Monitor", "Policy", "Security Center"]
  },
  "Container & Orchestration": ["Kubernetes", "Docker", "Amazon EKS", "Azure AKS", "Helm", "Kustomize", "Service Mesh"],
  "CI/CD & Automation": ["Jenkins", "GitHub Actions", "Azure DevOps", "GitLab CI", "ArgoCD", "Terraform", "Ansible", "CloudFormation", "Python", "Bash"],
  "Monitoring & Observability": ["Prometheus", "Grafana", "Splunk", "CloudWatch", "Azure Monitor", "ELK Stack", "Distributed Tracing"],
  "Security & Compliance": ["SOC 2 Type II", "HIPAA", "GDPR", "PCI-DSS", "IAM", "RBAC", "KMS", "Encryption", "Vulnerability Management"]
};

export const projects = [
  {
    id: 1,
    title: "Fortune 500 Healthcare Cloud Migration",
    challenge: "Migrate 500+ workloads from on-premise to AWS while maintaining HIPAA compliance and zero downtime",
    approach: [
      "Assessed current infrastructure identifying dependencies and compliance requirements",
      "Built automated migration pipelines using AWS Application Migration Service",
      "Implemented multi-region architecture with automated failover",
      "Created HIPAA-compliant security controls with encryption, access logging, and monitoring"
    ],
    results: [
      { metric: "Zero", label: "Downtime during migration" },
      { metric: "25%", label: "Infrastructure cost reduction" },
      { metric: "Zero", label: "HHS audit findings" },
      { metric: "35%", label: "Performance improvement" }
    ],
    technologies: ["AWS", "EC2", "RDS", "S3", "VPC", "CloudFormation", "Terraform", "Ansible", "Python"]
  },
  {
    id: 2,
    title: "Multi-Cloud Cost Optimization Platform",
    challenge: "Reduce cloud spending across healthcare, fintech, and SaaS clients without impacting performance",
    approach: [
      "Built automated cost analysis using AWS Cost Explorer and Azure Cost Management APIs",
      "Implemented rightsizing recommendations based on actual usage patterns",
      "Created auto-scaling policies adapting to traffic patterns",
      "Automated resource cleanup for idle and abandoned infrastructure"
    ],
    results: [
      { metric: "30-70%", label: "Cost reduction across clients" },
      { metric: "$2M+", label: "Annual savings delivered" },
      { metric: "80%", label: "Reduced manual analysis time" }
    ],
    technologies: ["Python", "Terraform", "AWS Lambda", "CloudWatch", "Azure Functions", "Grafana"]
  },
  {
    id: 3,
    title: "Kubernetes Security Hardening Initiative",
    challenge: "Secure 8 production Kubernetes clusters running sensitive workloads",
    approach: [
      "Implemented Pod Security Standards and network policies",
      "Configured RBAC with least-privilege access patterns",
      "Integrated automated vulnerability scanning in CI/CD",
      "Built security monitoring with Prometheus and Falco"
    ],
    results: [
      { metric: "30%", label: "Reduction in security incidents" },
      { metric: "100%", label: "SOC 2 & PCI-DSS compliance" },
      { metric: "Automated", label: "Security compliance checks" }
    ],
    technologies: ["Kubernetes", "Docker", "Snyk", "Trivy", "Prometheus", "Grafana", "Azure Policy"]
  },
  {
    id: 4,
    title: "Enterprise CI/CD Platform",
    challenge: "Build standardized deployment platform for 100+ engineers across 50+ microservices",
    approach: [
      "Created reusable pipeline templates with security scanning and automated testing",
      "Implemented GitOps workflows with ArgoCD for declarative deployments",
      "Built self-service infrastructure provisioning portal",
      "Integrated monitoring and alerting into deployment workflows"
    ],
    results: [
      { metric: "40%", label: "Reduction in deployment time" },
      { metric: "60%", label: "Fewer deployment failures" },
      { metric: "Eliminated", label: "Manual deployment bottlenecks" }
    ],
    technologies: ["Jenkins", "GitHub Actions", "ArgoCD", "Terraform", "Kubernetes", "Helm"]
  }
];

export const experience = [
  {
    id: 1,
    company: "Tambena Consulting",
    role: "DevOps/DevSecOps Engineer",
    period: "May 2023 - Present",
    highlights: [
      "Modernize cloud infrastructure for healthcare, fintech, and enterprise clients",
      "Led Fortune 500 healthcare migration",
      "Reduced client infrastructure costs 70% through automation and optimization",
      "Implemented compliance frameworks passing audits with zero critical findings"
    ]
  },
  {
    id: 2,
    company: "Yulys",
    role: "AWS Cloud & DevOps Engineer",
    period: "May 2021 - April 2023",
    highlights: [
      "Built and maintained AWS and Azure infrastructure for SaaS platform",
      "Saved $10,600 annually through cost optimization",
      "Achieved 99.95% uptime through high-availability architecture",
      "Implemented security standards and compliance measures"
    ]
  },
  {
    id: 3,
    company: "AceDataOps",
    role: "Cloud Engineer",
    period: "November 2017 - April 2021",
    highlights: [
      "Configured secure cloud infrastructure across AWS and Azure",
      "Automated compliance checks achieving 100% adherence to SOC 2 standards",
      "Built serverless applications reducing operational costs 40%",
      "Trained teams on cloud security best practices"
    ]
  },
  {
    id: 4,
    company: "ERESTAUPOS",
    role: "System Administrator",
    period: "June 2015 - September 2017",
    highlights: [
      "Managed 50+ servers maintaining 99.5% uptime",
      "Automated administrative tasks reducing manual effort 60%",
      "Implemented security hardening and patch management",
      "Built monitoring and alerting infrastructure"
    ]
  }
];

export const certifications = [
  { id: 1, name: "AWS Certified Solutions Architect - Professional", issuer: "Amazon Web Services", status: "active" },
  { id: 2, name: "AWS Certified Solutions Architect - Associate", issuer: "Amazon Web Services", status: "active" },
  { id: 3, name: "AWS Certified Cloud Practitioner", issuer: "Amazon Web Services", status: "active" },
  { id: 4, name: "CompTIA Security+", issuer: "CompTIA", status: "active" },
  { id: 5, name: "Microsoft Certified Azure Solutions Architect Expert", issuer: "Microsoft", status: "in-progress" },
  { id: 6, name: "Microsoft Certified Azure Administrator Associate", issuer: "Microsoft", status: "in-progress" }
];

export const education = [
  { id: 1, degree: "Master of Science in Health Services Administration", school: "Central Michigan University" },
  { id: 2, degree: "Bachelor of Science in Business Management", school: "St. Leo University" }
];

export const stats = [
  { id: 1, value: "9+", label: "Years Experience" },
  { id: 2, value: "500+", label: "Workloads Migrated" },
  { id: 3, value: "$2M+", label: "Annual Savings" },
  { id: 4, value: "99.9%", label: "Uptime Achieved" }
];

export const blogTopics = [
  { id: 1, title: "Cloud Cost Optimization", description: "The hidden costs in cloud infrastructure and practical strategies for reducing spend without sacrificing performance." },
  { id: 2, title: "HIPAA-Compliant Cloud Architecture", description: "Building healthcare infrastructure that balances security, compliance, and developer experience." },
  { id: 3, title: "Kubernetes Security in Production", description: "Practical security hardening beyond the basics. What actually matters when running production workloads." },
  { id: 4, title: "The Reality of Cloud Migrations", description: "What enterprise cloud migrations actually look like. The technical, organizational, and political challenges." },
  { id: 5, title: "Multi-Cloud Strategy", description: "When multi-cloud makes sense, when it doesn't, and how to implement it without doubling operational complexity." }
];

export const philosophy = [
  { id: 1, title: "Automation Over Documentation", description: "If you're documenting a manual process, you should probably be automating it instead." },
  { id: 2, title: "Guardrails Over Gates", description: "Security and compliance should enable developers to move fast safely, not slow them down." },
  { id: 3, title: "Observe, Then Optimize", description: "You can't optimize what you can't measure. Implement comprehensive monitoring first." },
  { id: 4, title: "Complexity is a Bug", description: "Every layer of complexity is a maintenance burden. Choose boring, proven technology." },
  { id: 5, title: "Fail Visibly", description: "Systems should fail loudly and obviously. Silent failures are the most expensive kind." }
];
