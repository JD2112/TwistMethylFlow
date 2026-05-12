(base) jyoda68 ~/Documents/TwistNext/containers/docker [new_devel] $ docker scout cves jd21/methylflow:1.1.0 --only-severity critical,high
    i New version 1.20.4 available (installed version is 1.20.3) at https://github.com/docker/scout-cli
    ✓ Image stored for indexing
    ✓ Indexed 968 packages
    ✓ Provenance obtained from attestation
    ✗ Detected 3 vulnerable packages with a total of 4 vulnerabilities


## Overview

                   │               Analyzed Image               
───────────────────┼────────────────────────────────────────────
 Target            │  jd21/methylflow:1.1.0                     
   digest          │  99aea85617e9                              
   platform        │ linux/amd64                                
   provenance      │ https://github.com/JD2112/TwistNext.git    
                   │  5e46fd98c01304e9c396d140ba2d7bf9fd333673  
   vulnerabilities │    0C     4H     0M     0L                 
   size            │ 3.8 GB                                     
   packages        │ 968                                        


## Packages and Vulnerabilities

   0C     2H     0M     0L  gnutls28 3.8.9-3+deb13u2
pkg:deb/debian/gnutls28@3.8.9-3%2Bdeb13u2?os_distro=trixie&os_name=debian&os_version=13

    ✗ HIGH CVE-2026-33846
      https://scout.docker.com/v/CVE-2026-33846
      Affected range : >0        
      Fixed version  : not fixed 
    
    ✗ HIGH CVE-2026-33845
      https://scout.docker.com/v/CVE-2026-33845
      Affected range : >0        
      Fixed version  : not fixed 
    

   0C     1H     0M     0L  glibc 2.41-12+deb13u2
pkg:deb/debian/glibc@2.41-12%2Bdeb13u2?os_distro=trixie&os_name=debian&os_version=13

    ✗ HIGH CVE-2026-5435
      https://scout.docker.com/v/CVE-2026-5435
      Affected range : >0        
      Fixed version  : not fixed 
    

   0C     1H     0M     0L  org.pf4j/pf4j 3.12.0
pkg:maven/org.pf4j/pf4j@3.12.0

    ✗ HIGH CVE-2025-70952 [Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')]
      https://scout.docker.com/v/CVE-2025-70952
      Affected range : <3.14.1                                                         
      Fixed version  : 3.14.1                                                          
      CVSS Score     : 8.7                                                             
      CVSS Vector    : CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:N/VI:H/VA:N/SC:N/SI:N/SA:N 
    


4 vulnerabilities found in 3 packages
  CRITICAL  0 
  HIGH      4 
  MEDIUM    0 
  LOW       0 


---

(base) jyoda68 ~/Documents/TwistNext/containers/docker [new_devel] $ docker scout cves jd21/methylflow-unified:1.1.0 --only-severity critical,high
    i New version 1.20.4 available (installed version is 1.20.3) at https://github.com/docker/scout-cli
    ✓ Image stored for indexing
    ✓ Indexed 312 packages
    ✓ Provenance obtained from attestation
    ✗ Detected 2 vulnerable packages with a total of 3 vulnerabilities


## Overview

                   │               Analyzed Image               
───────────────────┼────────────────────────────────────────────
 Target            │  jd21/methylflow-unified:1.1.0             
   digest          │  8525f9cfb2ea                              
   platform        │ linux/amd64                                
   provenance      │ https://github.com/JD2112/TwistNext.git    
                   │  5e46fd98c01304e9c396d140ba2d7bf9fd333673  
   vulnerabilities │    0C     3H     0M     0L                 
   size            │ 874 MB                                     
   packages        │ 312                                        


## Packages and Vulnerabilities

   0C     2H     0M     0L  gnutls28 3.8.9-3+deb13u2
pkg:deb/debian/gnutls28@3.8.9-3%2Bdeb13u2?os_distro=trixie&os_name=debian&os_version=13

    ✗ HIGH CVE-2026-33846
      https://scout.docker.com/v/CVE-2026-33846
      Affected range : >0        
      Fixed version  : not fixed 
    
    ✗ HIGH CVE-2026-33845
      https://scout.docker.com/v/CVE-2026-33845
      Affected range : >0        
      Fixed version  : not fixed 
    

   0C     1H     0M     0L  glibc 2.41-12+deb13u2
pkg:deb/debian/glibc@2.41-12%2Bdeb13u2?os_distro=trixie&os_name=debian&os_version=13

    ✗ HIGH CVE-2026-5435
      https://scout.docker.com/v/CVE-2026-5435
      Affected range : >0        
      Fixed version  : not fixed 
    


3 vulnerabilities found in 2 packages
  CRITICAL  0 
  HIGH      3 
  MEDIUM    0 
  LOW       0 

---

(base) jyoda68 ~/Documents/TwistNext/containers/docker [new_devel] $ docker scout cves jd21/methylflow-report:1.1.0 --only-severity critical,high
    i New version 1.20.4 available (installed version is 1.20.3) at https://github.com/docker/scout-cli
    ✓ Image stored for indexing
    ✓ Indexed 794 packages
    ✓ Provenance obtained from attestation
    ✗ Detected 3 vulnerable packages with a total of 20 vulnerabilities


## Overview

                   │               Analyzed Image               
───────────────────┼────────────────────────────────────────────
 Target            │  jd21/methylflow-report:1.1.0              
   digest          │  7e29eb2c8afb                              
   platform        │ linux/amd64                                
   provenance      │ https://github.com/JD2112/TwistNext.git    
                   │  5e46fd98c01304e9c396d140ba2d7bf9fd333673  
   vulnerabilities │    4C    27H     0M     0L                 
   size            │ 1.4 GB                                     
   packages        │ 794                                        


## Packages and Vulnerabilities

   3C    16H     0M     0L  stdlib 1.20.12
pkg:golang/stdlib@1.20.12

    ✗ CRITICAL CVE-2025-68121
      https://scout.docker.com/v/CVE-2025-68121
      Affected range : <1.24.13 
      Fixed version  : 1.24.13  
    
    ✗ CRITICAL CVE-2024-24790
      https://scout.docker.com/v/CVE-2024-24790
      Affected range : <1.21.11 
      Fixed version  : 1.21.11  
    
    ✗ CRITICAL CVE-2025-22871
      https://scout.docker.com/v/CVE-2025-22871
      Affected range : <1.23.8 
      Fixed version  : 1.23.8  
    
    ✗ HIGH CVE-2026-32283
      https://scout.docker.com/v/CVE-2026-32283
      Affected range : <1.25.9 
      Fixed version  : 1.25.9  
    
    ✗ HIGH CVE-2026-32281
      https://scout.docker.com/v/CVE-2026-32281
      Affected range : <1.25.9 
      Fixed version  : 1.25.9  
    
    ✗ HIGH CVE-2026-32280
      https://scout.docker.com/v/CVE-2026-32280
      Affected range : <1.25.9 
      Fixed version  : 1.25.9  
    
    ✗ HIGH CVE-2026-25679
      https://scout.docker.com/v/CVE-2026-25679
      Affected range : <1.25.8 
      Fixed version  : 1.25.8  
    
    ✗ HIGH CVE-2025-61729
      https://scout.docker.com/v/CVE-2025-61729
      Affected range : <1.24.11 
      Fixed version  : 1.24.11  
    
    ✗ HIGH CVE-2025-61726
      https://scout.docker.com/v/CVE-2025-61726
      Affected range : <1.24.12 
      Fixed version  : 1.24.12  
    
    ✗ HIGH CVE-2025-61725
      https://scout.docker.com/v/CVE-2025-61725
      Affected range : <1.24.8 
      Fixed version  : 1.24.8  
    
    ✗ HIGH CVE-2025-61723
      https://scout.docker.com/v/CVE-2025-61723
      Affected range : <1.24.8 
      Fixed version  : 1.24.8  
    
    ✗ HIGH CVE-2025-58188
      https://scout.docker.com/v/CVE-2025-58188
      Affected range : <1.24.8 
      Fixed version  : 1.24.8  
    
    ✗ HIGH CVE-2025-58187
      https://scout.docker.com/v/CVE-2025-58187
      Affected range : <1.24.9 
      Fixed version  : 1.24.9  
    
    ✗ HIGH CVE-2024-34158
      https://scout.docker.com/v/CVE-2024-34158
      Affected range : <1.22.7 
      Fixed version  : 1.22.7  
    
    ✗ HIGH CVE-2024-34156
      https://scout.docker.com/v/CVE-2024-34156
      Affected range : <1.22.7 
      Fixed version  : 1.22.7  
    
    ✗ HIGH CVE-2024-24791
      https://scout.docker.com/v/CVE-2024-24791
      Affected range : <1.21.12 
      Fixed version  : 1.21.12  
    
    ✗ HIGH CVE-2024-24784
      https://scout.docker.com/v/CVE-2024-24784
      Affected range : <1.21.8 
      Fixed version  : 1.21.8  
    
    ✗ HIGH CVE-2023-45288
      https://scout.docker.com/v/CVE-2023-45288
      Affected range : <1.21.9 
      Fixed version  : 1.21.9  
    
    ✗ HIGH CVE-2022-30635
      https://scout.docker.com/v/CVE-2022-30635
      Affected range : <1.22.7 
      Fixed version  : 1.22.7  
    

   1C    10H     0M     0L  stdlib 1.23.12
pkg:golang/stdlib@1.23.12

    ✗ CRITICAL CVE-2025-68121
      https://scout.docker.com/v/CVE-2025-68121
      Affected range : <1.24.13 
      Fixed version  : 1.24.13  
    
    ✗ HIGH CVE-2026-32283
      https://scout.docker.com/v/CVE-2026-32283
      Affected range : <1.25.9 
      Fixed version  : 1.25.9  
    
    ✗ HIGH CVE-2026-32281
      https://scout.docker.com/v/CVE-2026-32281
      Affected range : <1.25.9 
      Fixed version  : 1.25.9  
    
    ✗ HIGH CVE-2026-32280
      https://scout.docker.com/v/CVE-2026-32280
      Affected range : <1.25.9 
      Fixed version  : 1.25.9  
    
    ✗ HIGH CVE-2026-25679
      https://scout.docker.com/v/CVE-2026-25679
      Affected range : <1.25.8 
      Fixed version  : 1.25.8  
    
    ✗ HIGH CVE-2025-61729
      https://scout.docker.com/v/CVE-2025-61729
      Affected range : <1.24.11 
      Fixed version  : 1.24.11  
    
    ✗ HIGH CVE-2025-61726
      https://scout.docker.com/v/CVE-2025-61726
      Affected range : <1.24.12 
      Fixed version  : 1.24.12  
    
    ✗ HIGH CVE-2025-61725
      https://scout.docker.com/v/CVE-2025-61725
      Affected range : <1.24.8 
      Fixed version  : 1.24.8  
    
    ✗ HIGH CVE-2025-61723
      https://scout.docker.com/v/CVE-2025-61723
      Affected range : <1.24.8 
      Fixed version  : 1.24.8  
    
    ✗ HIGH CVE-2025-58188
      https://scout.docker.com/v/CVE-2025-58188
      Affected range : <1.24.8 
      Fixed version  : 1.24.8  
    
    ✗ HIGH CVE-2025-58187
      https://scout.docker.com/v/CVE-2025-58187
      Affected range : <1.24.9 
      Fixed version  : 1.24.9  
    

   0C     1H     0M     0L  linux 6.8.0-110.110
pkg:deb/ubuntu/linux@6.8.0-110.110?os_distro=noble&os_name=ubuntu&os_version=24.04

    ✗ HIGH CVE-2026-31431  CISA KEV 
      https://scout.docker.com/v/CVE-2026-31431
      Affected range : >=0       
      Fixed version  : not fixed 
    


31 vulnerabilities found in 3 packages
  CRITICAL  4  
  HIGH      27 
  MEDIUM    0  
  LOW       0  


---

(base) jyoda68 ~/Documents/TwistNext/containers/docker [new_devel] $ docker scout cves jd21/methylflow-enrich:1.1.0 --only-severity critical,high
    i New version 1.20.4 available (installed version is 1.20.3) at https://github.com/docker/scout-cli
    ✓ Image stored for indexing
    ✓ Indexed 629 packages
    ✓ Provenance obtained from attestation
    ✗ Detected 1 vulnerable package with 6 vulnerabilities


## Overview

                   │               Analyzed Image               
───────────────────┼────────────────────────────────────────────
 Target            │  jd21/methylflow-enrich:1.1.0              
   digest          │  5b4f6a391d1e                              
   platform        │ linux/amd64                                
   provenance      │ https://github.com/JD2112/TwistNext.git    
                   │  5e46fd98c01304e9c396d140ba2d7bf9fd333673  
   vulnerabilities │    0C     6H     0M     0L                 
   size            │ 1.5 GB                                     
   packages        │ 629                                        


## Packages and Vulnerabilities

   0C     6H     0M     0L  linux 5.15.0-176.186
pkg:deb/ubuntu/linux@5.15.0-176.186?os_distro=jammy&os_name=ubuntu&os_version=22.04

    ✗ HIGH CVE-2025-38118
      https://scout.docker.com/v/CVE-2025-38118
      Affected range : >=0                                          
      Fixed version  : not fixed                                    
      CVSS Score     : 7.8                                          
      CVSS Vector    : CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H 
    
    ✗ HIGH CVE-2025-37899
      https://scout.docker.com/v/CVE-2025-37899
      Affected range : >=0                                          
      Fixed version  : not fixed                                    
      CVSS Score     : 7.8                                          
      CVSS Vector    : CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H 
    
    ✗ HIGH CVE-2024-53179
      https://scout.docker.com/v/CVE-2024-53179
      Affected range : >=0                                          
      Fixed version  : not fixed                                    
      CVSS Score     : 7.8                                          
      CVSS Vector    : CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H 
    
    ✗ HIGH CVE-2024-56692
      https://scout.docker.com/v/CVE-2024-56692
      Affected range : >=0                                          
      Fixed version  : not fixed                                    
      CVSS Score     : 5.5                                          
      CVSS Vector    : CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:N/I:N/A:H 
    
    ✗ HIGH CVE-2026-31431  CISA KEV 
      https://scout.docker.com/v/CVE-2026-31431
      Affected range : >=0       
      Fixed version  : not fixed 
    
    ✗ HIGH CVE-2024-35870
      https://scout.docker.com/v/CVE-2024-35870
      Affected range : >=0       
      Fixed version  : not fixed 
    
