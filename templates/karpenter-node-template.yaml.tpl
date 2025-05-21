apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: ${node_class_name}
spec:
  amiFamily: ${ami_family}
  amiSelectorTerms:
    - alias: ${ami_selector_terms_alias}



%{ if use_subnet_ids }
  subnetSelectorTerms:
%{ for id in subnet_ids }
    - id: ${id}
%{ endfor }
%{ else }
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${cluster_name}
%{ endif }


%{ if use_security_group_ids }
  securityGroupSelectorTerms:
%{ for id in security_group_ids }
    - id: ${id}
%{ endfor }
%{ else }
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${cluster_name}
%{ endif }



  role: ${node_role}
  tags:
    karpenter.sh/discovery: ${cluster_name}
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: ${disk_size}
        volumeType: gp3
        deleteOnTermination: true
        encrypted: true
  detailedMonitoring: false
  
  # EC2 instance metadata service configuration
  # Enhanced security settings for IMDS:
  # - httpEndpoint enabled: Required for basic instance functionality
  # - httpProtocolIPv6 disabled: Reduces attack surface
  # - httpPutResponseHopLimit 2: Allows kubelet while preventing unauthorized access
  # - httpTokens required: Enforces IMDSv2 for improved security against SSRF attacks
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: 2
    httpTokens: required  # Requires IMDSv2 for better security
