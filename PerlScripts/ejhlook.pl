=pod

=begin PerlCtrl

    %TypeLib = (
	PackageName     => 'MyPackage::MyName',
        DocString       => 'My very own control',
        HelpFileName    => 'MyControl.chm',
        HelpContext     => 1,
	TypeLibGUID     => '{5539AA77-DA32-4826-B5DE-E3607996B381}', # do NOT edit this line
	ControlGUID     => '{AD0EC99D-8D3E-41F6-A09F-9713327F78DD}', # do NOT edit this line either
	DispInterfaceIID=> '{D0174941-42CF-4F34-A430-9030D2FD8989}', # or this one
	ControlName     => 'MyObject',
	ControlVer      => 1,  # increment if new object with same ProgID
			       # create new GUIDs as well
	ProgID          => 'MyApp.MyObject',
        LCID            => 0,
	DefaultMethod   => 'MyMethodName1',
	Methods         => {
	    MyMethodName1 => {
                DocString           => "The MyMethodName1 method",
                HelpContext         => 101,

                DispID              =>  0,
		RetType             =>  VT_I4,
		TotalParams         =>  5,
		NumOptionalParams   =>  2,
		ParamList           =>[ ParamName1 => VT_I4,
					ParamName2 => VT_BSTR,
					ParamName3 => VT_BOOL,
					ParamName4 => VT_I4,
					ParamName5 => VT_UI1 ],
	    },
	    MyMethodName2 => {
                DocString           => "The MyMethodName2 method",
                HelpContext         => 102,

                DispID              =>  1,
		RetType             =>  VT_I4,
		TotalParams         =>  2,
		NumOptionalParams   =>  0,
		ParamList           =>[ ParamName1 => VT_I4,
					ParamName2 => VT_BSTR ],
	    },
	},  # end of 'Methods'
	Properties        => {
	    MyIntegerProp => {
                DocString         => "The MyIntegerProp property",
                HelpContext       => 201,

                DispID            => 2,
		Type              => VT_I4,
		ReadOnly          => 0,
	    },
	    MyStringProp => {
                DocString         => "The MyStringProp property",
                HelpContext       => 202,

                DispID            => 3,
		Type              => VT_BSTR,
		ReadOnly          => 0,
	    },
	    Color => {
                DocString         => "The Color property",
                HelpContext       => 203,

                DispID            => 4,
		Type              => VT_BSTR,
		ReadOnly          => 0,
	    },
	    MyReadOnlyIntegerProp => {
                DocString         => "The MyReadOnlyIntegerProp property",
                HelpContext       => 204,

                DispID            => 5,
		Type              => VT_I4,
		ReadOnly          => 1,
	    },
	},  # end of 'Properties'
    );  # end of %TypeLib

=end PerlCtrl

=cut
