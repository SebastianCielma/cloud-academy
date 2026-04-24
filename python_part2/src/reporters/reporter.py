import json
from collections import defaultdict
from typing import List
from src.models.findings import Finding, FindingType, Severity
from src.models.resources import EnvironmentState

class Reporter:
    def __init__(self, findings: List[Finding], actual_state: EnvironmentState):
        self.findings = findings
        self.actual_state = actual_state

    def generate_console_report(self):
        total_resources = (
            len(self.actual_state.instances) +
            len(self.actual_state.security_groups) +
            len(self.actual_state.buckets)
        )
        
        drift_findings = [f for f in self.findings if f.finding_type != FindingType.POLICY_VIOLATION]
        policy_findings = [f for f in self.findings if f.finding_type == FindingType.POLICY_VIOLATION]
        
        severity_counts = defaultdict(int)
        for f in self.findings:
            severity_counts[f.severity.value] += 1

        print("\n" + "="*70)
        print(" TECHNICAL COMPLIANCE REPORT ")
        print("="*70)
        
        for f in self.findings:
            print(f"[{f.severity.value}] {f.finding_type.value} | resource_type={f.resource_type} | "
                  f"resource={f.resource_name} | reason={f.reason}")
        
        print("\n" + "-"*70)
        print(" SUMMARY ")
        print("-"*70)
        print(f"Total resources analyzed: {total_resources}")
        print(f"Total findings:           {len(self.findings)}")
        print(f"Drift findings:           {len(drift_findings)}")
        print(f"Policy violations:        {len(policy_findings)}")
        
        print("\nSeverity Breakdown:")
        for sev in [Severity.CRITICAL, Severity.HIGH, Severity.MEDIUM, Severity.LOW]:
            print(f" - {sev.value}: {severity_counts[sev.value]}")
            
        critical_issues = [f for f in self.findings if f.severity == Severity.CRITICAL]
        if critical_issues:
            print("\nTop Critical Issues:")
            for issue in critical_issues[:5]: 
                print(f" * {issue.resource_name} ({issue.resource_type}): {issue.reason}")
        print("="*70 + "\n")

    def export_to_json(self, output_path: str = "report.json"):
        export_data = []
        for f in self.findings:
            finding_dict = {
                "finding_type": f.finding_type.value,
                "resource_type": f.resource_type,
                "resource_name": f.resource_name,
                "severity": f.severity.value,
                "reason": f.reason,
            }
            if f.expected is not None:
                finding_dict["expected"] = f.expected
            if f.actual is not None:
                finding_dict["actual"] = f.actual
                
            export_data.append(finding_dict)

        with open(output_path, 'w', encoding='utf-8') as outfile:
            json.dump(export_data, outfile, indent=4)