# OVSF Generator component

## Component description

The OVSF Generator component implements generation of OVSF code for the specified spread factor.
The OVSF codes are used in telecommunication systems, particularily in WCDMA. A Good explanation of the algorithm can be found at https://www.mathworks.com/help/comm/ref/ovsfcodegenerator.html.

## Interface

Parameters:

* SF_WIDTH - the power of 2 to achieve the desired spreading factor. Supported values from 2 up to 8.

Ports:

* s_axis_config_tvalid - one-bit signal. It indicates a new configuration.
* s_axis_config_tdata - 8-bit bus. The value of OVSF number that should be generated. The valid values are from 0 up to (2^SF_WIDTH)-1.
* m_axis_data_tvalid - one-bit signal. It indicates that the component is ready to provide the generated OVSF-code.
* m_axis_data_tready - one-bit signal. If it is set to low the component will stall.
* m_axis_data_tlast - one-bit signal. It indicates that the current item of the OVSF-code is the last one.
* m_axis_data_tdata - 8-bit signal. The 0th bit represents actual value of the OVSF-code item. 0 stands for +1 and 1 stands for -1. Other bits are reserved and grounded.
* m_axis_data_tuser - 8-bit signal. Indicates position of the current element in the OVSF-code sequence.

## Implementation description

After a reset the component is in an idle state. When it receives the configuration on s_axis_config_ bus, it begins to generate the required OVSF-code sequence. It generates the sequences infinitely, so when the component has generated the last item of the sequence, it will begin generate the same sequence again.

The component can be reconfigured at any time, the new configuration will be appliead after the component gives the last item of the sequence.

The m_axis_data_tready signal can control the output of the component.
