# p4srv6 ... proto-typing SRv6 functions with P4 lang.

> P4-16 version on v1model will be published in March 2019. Stay Tuned!!  
> Contents of this README.md is replaced with P4-16 version.  
> Old P4-14 version is moved under [p4-14](https://github.com/ebiken/p4srv6/tree/master/p4-14) for archival purpose.  

The objective of this project is to implement SRv6 functions still under discussion using P4 Lang to make running code available for testing and demo. Since there is no Open Source P4 switch implementation supporting SRv6, this should include basic switch features required to test SRv6.

This project was started as part of SRv6 Mobile User Plane POC conducted in [SRv6 consortium](https://seg6.net).
Thus current priority is functions from [Mobile Uplane draft](https://datatracker.ietf.org/doc/draft-ietf-dmm-srv6-mobile-uplane/).
But planning to expand to general [SRv6 Network Programming](https://datatracker.ietf.org/doc/draft-filsfils-spring-srv6-network-programming/) functions for Edge Computing and Data Center use cases.

Please raise issue with use case description if you want to any SRv6 functions not implemented yet.

## P4 Target and Architecture

This is written for v1model architecture and confirmed to run on [BMv2](https://github.com/p4lang/behavioral-model).

I am trying to make as most code common among different architectures as possible.

Following Target Architectures are in my mind. Any contribution is more than welcome. :)
* v1model : [v1model.p4](https://github.com/p4lang/p4c/blob/master/p4include/v1model.p4) (Supported)
* PSA : [psa.p4](https://github.com/p4lang/p4c/blob/master/p4include/psa.p4)
* p4c-xdp : [xdp_model.p4](https://github.com/vmware/p4c-xdp/blob/master/p4include/xdp_model.p4) 
* Tofino Model
* SmartNIC ??

## List of SRv6 functions of interest and status (a.k.a. Road Map)
* Basic Switching Features (Layer 1/2/3)
    * Available
        * port forwarding table
        * dmac table (Static Layer 2 forwarding)
    * Planned near future
        * VLAN
        * Layer forwarding (FIBv4, FIBv6)
        * mac learning agent (dynamic dmac table update based on smac)
* [draft-ietf-dmm-srv6-mobile-uplane-03](https://datatracker.ietf.org/doc/draft-ietf-dmm-srv6-mobile-uplane/)
    * Available
        * T.M.Tmap
        * End.M.GTP4.E
    * Planned near future
        * End.M.GTP6.D
        * End.M.GTP6.E
* [draft-filsfils-spring-srv6-network-programming-07](https://datatracker.ietf.org/doc/draft-filsfils-spring-srv6-network-programming/)
    * Available
    	* T.Insert
        * End (without error handling)
    * Planned near future
        * PSP behavior
        * T.Encaps, T.Encaps.L2, T.Encaps.Red
    	* End.DT4, End.DT6

