Class DataPopulation.Utils Extends %RegisteredObject
{

/// Display the methods of DataPopulation.Utils and their usage.
/// Methods include:
/// 	EnablePopulate
/// 	DisablePopulate
/// 	
/// There typically isn't a use case for using 
ClassMethod Help(allMethods As %Boolean = 0)
{
}

/// Adds %Populate as a superclass to relevant classes in a package, saves, and compiles them.
/// Takes in package as %String, returns %Status. 
ClassMethod AddPopulateSuper(classes As %String = "", verbose As %Boolean = 0, rollbackOnError As %Boolean = 1) As %Status
{
	set st = $$$OK 

	// If a string is passed in, assume package, retrieve a set of classes under that package.
	// If there is no array under classes, exit function.
	if ($g(classes) '= "") d ..GetClasses(classes,.classes)
	if (($data(classes) '= 10) && ($data(classes) '= 11)) return st
	set clsName = ""
	set tLevelInitial = $TLEVEL
	if rollbackOnError TSTART
	
	;===Begin for loop over classes in the package and add %Populate as a superclass if possible.
	for {
		
		set clsName = $o(classes(clsName))
		if (clsName = "") {
			set st = $system.OBJ.Compile(.classes,$s($g(verbose):"d",1:"-d")_"u")
			quit
		}
		set clsDef = ##class(%Dictionary.ClassDefinition).%OpenId(clsName)
		continue:('$ISOBJECT(clsDef))
		
		;%DataType classes cannot extend %Populate.
		if (($classmethod(clsName,"%Extends","%DataType") = 0) && (clsDef.Super '= "")) {
			set extendsPopulate = $classmethod(clsName,"%Extends","%Populate"), 
				extendsSerialObject = $classmethod(clsName,"%Extends","%SerialObject"),
				extendsPersistent = $classmethod(clsName,"%Extends","%Persistent")
			
			;If the class doesn't already extend %Populate AND it extends either %Persistent or %SerialObject,
			;we can add %Populate as a superclass.
			if (('extendsPopulate) && ('(clsDef.Abstract)) && (extendsSerialObject || extendsPersistent)) {
				set clsDef.Super = clsDef.Super _ ",%Populate"
			}
			try { 
				$$$TOE(st,clsDef.%Save())
			}	catch exc {
				set st = exc.AsStatus()
				quit
			}
}
		
	} ; ===End for loop over classes in package.
		
	if $system.Status.IsError(st) {
		if rollbackOnError while $TLEVEL > tLevelInitial { TROLLBACK 1 }
		if verbose d $system.Status.DisplayError(st)
	}
	else {
		if rollbackOnError TCOMMIT
	}
	
	return st
}

ClassMethod SetPOPSPEC(class As %String = "", property As %String = "", pMethod As %String = "") As %Status
{
	set st = $$$OK
	set prop = ##class(%Dictionary.PropertyDefinition).%OpenId(class_"||"_property)
	if prop = "" return st
	return st
}

/// Adds POPSPEC parameter to relevant properties in package based on property data type.
/// Takes in package, returns data type. 
/// /// PARAMETERS:
/// 	classes is a single package, a single class, or a node array of classes passed by reference.
/// 		These classes will have their Populate method invoked.
/// 	numPop specifies the amount of objects that we will try to create with Populate. 
/// 	tune controls whether Tune Table is run after all populated objects for the class have been saved.
/// 		If tune is not true, Tune Table is not run.
/// 		If tune is true, Tune Table is run.
/// 		If tune > 1, Tune Table is also run for any tables projected by persistent superclasses of each class in parameter classes.
/// 	If verbose is true, error messages, compilation output, and population logs are displayed.
ClassMethod AddPOPSPEC(classes = "", verbose As %Boolean = 0, rollbackOnError As %Boolean = 1) As %Status
{
	set st = $$$OK
	;if ($g(package) '= "" && $data(package)) 
	if ($g(classes) '= "") d ..GetClasses(classes,.classes)
	if (($data(classes) '= 10) && ($data(classes) '= 11)) return st
	set clsName = "" 
	if rollbackOnError {
		set tLevelInitial = $TLEVEL
		TSTART 
	}
	
	for { 	; ===Begin for loop over classes in the package.
		
		set clsName = $o(classes(clsName))
		if (clsName = "") {
			set st = $system.OBJ.Compile(.classes,$s($g(verbose):"d",1:"-d")_"u")
			quit
		}

		set clsDef = ##class(%Dictionary.ClassDefinition).%OpenId(clsName)
		continue:('$ISOBJECT(clsDef))
		
		if $classmethod(clsName,"%Extends","%Populate") {
						
			set key = ""
			for { ; =====Begin for loop over properties in the class. 
				set propDef = clsDef.Properties.GetNext(.key)
				quit:(propDef = "")
				set popspecVal = ..GeneratePOPSPECMethod(propDef.%Id())
				continue:(popspecVal = "")
				
				d propDef.Parameters.SetAt(popspecVal,"POPSPEC")
				
			} ; =====End for loop over properties in the class.
			
			try {
				$$$TOE(st,clsDef.%Save())
			} catch exc {
				set st = exc.AsStatus()
				quit
			}
			
		}
	} 	; ===End for loop over classes in the package.

	if $system.Status.IsError(st) {
		if rollbackOnError while $TLEVEL > tLevelInitial { TROLLBACK 1 }
		if verbose d $system.Status.DisplayError(st)
	}
	else {
		if rollbackOnError TCOMMIT
	}
	
	return st
}

/// Generates an appropriate POPSPEC parameter method for a data type property.
/// PARAMETERS:
/// 	propId is the ID of a property as defined in %Dictionary.PropertyDefinition.
/// The return value is a %String representing a POPSPEC method appropriate to the property's data type and constraints.
ClassMethod GeneratePOPSPECMethod(propId As %String = "") As %String
{
	
	set popspecVal = "", propDef = ##class(%Dictionary.PropertyDefinition).%OpenId(propId)
	if propDef = "" return popspecVal

	; propClsName is the name of the class associated with the property's type, e.g. a data type, persistent class, or serial class.
	; clsName is the name of the class containing the property.
	set propClsName = propDef.Type, clsName = propDef.parent.Name

	set isDatatype = $classmethod($$$NormalizeClassname(propClsName),"%Extends","%DataType")
	
	; If property is any of: a non-datatype, a collection, or a relationship, no need to generate POPSPEC.
	if (('isDatatype) || propDef.Collection || propDef.Relationship) return popspecVal

	; Retrieve the datatype class (e.g. %String, %Integer) of the property.
	; If %Library datatype, retrieve that datatype.
	; Else, second to last element in superclass list of oddCOM yields data type.
	set dt = ""
	if $$$ClassPackageName($$$NormalizeClassname(propClsName)) = "%Library" {
		set dt = $$$DenormalizeClassname(propClsName)
	}
	else {
		$$$comClassKeyGetLvar(sprClsList,propClsName,45)
		set sprClsList = $listfromstring(sprClsList,"~")
		set dt = $$$DenormalizeClassname($list(sprClsList,*-2))
	}
	
	
	; Many of the following datatype checks were derived from %Library.Populate:Populate.

	; Gather metadata on property data type. Restrictions will be considered in POPSPEC generation.
	$$$comMemberArrayGetLvar(valueList,clsName,"a",propDef.Name,"P","VALUELIST")
	if valueList = "" $$$comMemberArrayGetLvar(valueList,clsName,"a",propDef.Name,"P","DISPLAYLIST")
	$$$comMemberArrayGetLvar(minLen,clsName,"a",propDef.Name,"P","MINLEN")
	$$$comMemberArrayGetLvar(maxLen,clsName,"a",propDef.Name,"P","MAXLEN")
	$$$comMemberArrayGetLvar(minVal,clsName,"a",propDef.Name,"P","MINVAL")
	$$$comMemberArrayGetLvar(maxVal,clsName,"a",propDef.Name,"P","MAXVAL")
	$$$comMemberArrayGetLvar(scale,clsName,"a",propDef.Name,"P","SCALE")
	
	if valueList '= "" {
		set popspecVal = "ValueList("_$$$quote(valueList)_")"
	}
	elseif  ((minLen > 1) && ((dt = "%String") || (dt = "%Binary"))) {
		set popspecVal = "StringMin("_minLen_","_maxLen_")"
	}
	else {
		; ***** Some obscure data types may not be covered here, but can be added. 
		; e.g. %ExactString is obscure, have added it
		set popspecVal = $case(dt,
			"%String":		"String("_maxLen_")",
			"%ExactString":	"String("_maxLen_")",
			"%Integer":		"Integer("_minVal_","_maxVal_")",
			"%Date":		"Date("_minVal_","_maxVal_")",
			"%Binary":		"String("_maxLen_")",
			"%Double":		"Float("_minVal_","_maxVal_","_scale_")",
			"%Boolean":		"Random(2)",
			"%Currency":	"Currency("_minVal_","_maxVal_")",
			"%Float":		"Float("_minVal_","_maxVal_","_scale_")",
			"%Numeric":		"Float("_minVal_","_maxVal_","_scale_")",
			"%Decimal":		"Float("_minVal_","_maxVal_","_scale_")",
			"%PosixTime":	"PosixTime("_$$$quote(minVal)_","_$$$quote(maxVal)_")",
			"%TimeStamp":	"TimeStamp("_$$$quote(minVal)_","_$$$quote(maxVal)_")",
			:				"")		
	}
	
	; If none of the above, then perhaps the property is one of these datatypes:
	if popspecVal = "" {
		if dt = "%SmallInt" {
			Set maxVal = $Select(maxVal="":32767,maxVal>32767:32767,1:maxVal)
			Set minVal = $Select(minVal="":-32768,minVal<-32768:-32768,1:minVal)
			Set popspecVal = "Integer("_minVal_","_maxVal_")"
		}
		elseIf dt = "%Time" {
			Set maxVal = $Select(maxVal="":86399,maxVal>86399:86399,1:maxVal)
			Set minVal = $Select(minVal="":0,minVal<0:0,1:minVal)
			Set popspecVal = "Integer("_minVal_","_maxVal_")"
		}
		elseif dt = "%TinyInt" {
			Set maxVal = $Select(maxVal="":127,maxVal>127:127,1:maxVal)
			Set minVal = $Select(minVal="":-128,minVal<-128:-128,1:minVal)
			Set popspecVal = "Integer("_minVal_","_maxVal_")"
		}
		elseif dt = "%BigInt" {
			Set maxVal = $Select(maxVal="":100000000000000000,maxVal>100000000000000000:100000000000000000,1:maxVal)
			Set minVal = $Select(minVal="":-100000000000000000,minVal<-100000000000000000:-100000000000000000,1:minVal)
			Set popspecVal = "Integer("_minVal_","_maxVal_")"
		}
	}
	return popspecVal
}

/// Run Populate on every class in a package.
/// PARAMETERS:
/// 	classes is a single package, a single class, or a node array of classes passed by reference.
/// 		These classes will have their Populate method invoked.
/// 	numPop specifies the amount of objects that we will try to create with Populate. 
/// 	tune controls whether Tune Table is run after all populated objects for the class have been saved.
/// 		If tune is not true, Tune Table is not run.
/// 		If tune is true, Tune Table is run.
/// 		If tune > 1, Tune Table is also run for any tables projected by persistent superclasses of each class in parameter classes.
/// 	If verbose is true, error messages, compilation output, and population logs are displayed.
ClassMethod PopulateClasses(classes = "", numPop As %Integer = 10, tune As %Integer = 0, verbose As %Boolean = 0) As %Status
{
	
	set st = $$$OK
	if ($g(classes) '= "") d ..GetClasses(classes,.classes)
	if (($data(classes) '= 10) && ($data(classes) '= 11)) return st
	set clsName = "" 
	
	for {
		set clsName = $o(classes(clsName))
		quit:(clsName = "")
		set st = $system.Status.AppendStatus(st,..PopulateByProperties(clsName,numPop,tune,verbose))
	}
		
	if (verbose && $system.Status.IsError(st)) d $system.Status.DisplayError(st)
	k ^||popClasses
	return st
}

/// PARAMETERS:
/// 	class is a single class that we will check for any properties of a another class type that must have Populate run first.
/// 		This class will have Populate run if no dependent properties, all dependent properties have had Pppulate run, or there is a circular Populate dependence.
/// 	numPop specifies the amount of objects that we will try to create with Populate. 
/// 	tune controls whether Tune Table is run after all populated objects for the class have been saved.
/// 		If tune is not true, Tune Table is not run.
/// 		If tune is true, Tune Table is run.
/// 		If tune > 1, Tune Table is also run for any tables projected by persistent superclasses of each class in parameter classes.
/// 	If verbose is true, error messages, compilation output, and population logs are displayed.
ClassMethod PopulateByProperties(class As %String, numPop As %Integer = 10, tune As %Integer = 0, verbose As %Boolean = 0) As %Status
{
	
	set st = $$$OK

	; If class is already in population dependency tree, do not Populate just yet.
	; We'll fall into this case if there is a circular dependency in the tree.
	; All classes in the tree will be in popClasses, 
	if $d(^||popClasses(class)) return st	
	
	
	set clsDef = ##class(%Dictionary.ClassDefinition).%OpenId(class)
	
	; If this class extends %Populate but is not a %SerialObject, data type, or abstract class, can try to invoke Populate.
	set extendsPopulate = $classmethod(class,"%Extends","%Populate"), 
		extendsSerialObject = $classmethod(class,"%Extends","%SerialObject"),
		isDatatype = $classmethod(class,"%Extends","%DataType")
		
	if ((extendsPopulate) && ('extendsSerialObject) && ('isDatatype)) {

		; Set PPG to avoid endless population dependency loop.
		set ^||popClasses(class) = ""
		
		; We iterate over the properties in class.
		; When the class has a property, propDef, that is of another class's type, persistent, and has Populate enabled, AND either:
			; propDef is marked as Required
			; propDef is a Relationship where class is the many or the child.
		; The class type of propDef takes precedence over the current class. We try populating that class first.
		set key = ""
		for { ; === Begin for loop over properties in the class. 
			set propDef = clsDef.Properties.GetNext(.key)
			quit:(propDef = "")
			
			; If has necessary property whose type is Persistent, populate that property's class first.
			if ((propDef.Required) && ($classmethod(propDef.Type,"%Extends","%Persistent"))) {
				set st = $system.Status.AppendStatus(st,..PopulateByProperties(propDef.Type, numPop, tune, verbose))
			}
			; If has Relationship property of one or many, populate the other class first.
			if ((propDef.Relationship = 1) && ((propDef.Cardinality = "one") || (propDef.Cardinality = "parent"))) {
				set st = $system.Status.AppendStatus(st,..PopulateByProperties(propDef.Type, numPop, tune, verbose))
			}

		} ; === End for loop over properties in the class. 

		; All dependent properties have had Populate run, now try to Populate the class itself.
		if $d(^||popClasses(class)) {
			; Populate's parameters are: count, verbose, DeferIndices, ByRef objects, tune, deterministic 
			set numPopulated = $classmethod(class,"Populate",numPop,verbose,,,tune)
			if verbose w !,"Populating: ",class,": ",numPopulated
			set ^||popClasses(class) = numPopulated
		}
	}
	return st
}

/// !!!!! IN PROGRESS !!!!!
/// !!! Consider: Should I be including the case where package is a single class?
/// !!! Consider: Should I be including subpackages under package? 
/// 		Say Sample is passed in as package. Should Sample.Animals.Dog be retrieved with Sample.Person?
/// PARAMETERS:
/// 	package is a string representing either a single package or a single class.
/// 		If package represents a single package, get all classes under that package.
/// 		If package represents a single class, get that class.
/// 		NOTE: package is case-sensitive.
/// 	classes is an output parameter returning a node array where class names are subscripts.
ClassMethod GetClasses(package As %String = "", ByRef classes) As %Status
{
	set st = $$$OK
	if ##class(%Dictionary.ClassDefinition).%ExistsId(package) {
		set classes(package) = ""
		return st
	}
	set query = "SELECT ID FROM %Dictionary.ClassDefinition WHERE ID %STARTSWITH ?",
		package = package_"."
	set tStatement = ##class(%SQL.Statement).%New()
	d tStatement.%Prepare(query)
	set rs = tStatement.%Execute(package)
	while rs.%Next() {
		set classes(rs.%Get("ID")) = ""	
	}
	return st
}

/// For every applicable class given in parameter classes, add %Populate as a superclass.
/// Add POPSPEC for every applicable property in these classes.
/// PARAMETERS:
/// 	classes is a single package, a single class, or a node array of classes passed by reference.
/// 		These classes will have %Populate added as a superclass and POPSPEC added as a property parameter where suited.
/// 	numPop specifies the amount of objects that we will try to create with Populate. 
/// 	tune controls whether Tune Table is run after all populated objects have been saved.
/// 		If tune is not true, Tune Table is not run.
/// 		If tune is true, Tune Table is run.
/// 		If tune > 1, Tune Table is also run for any tables projected by persistent superclasses of each class in parameter classes.
/// 	If verbose is true, error messages, compilation output, and population logs are displayed.
/// 	If rollbackOnError is true, we rollback changes to classes on encountering an error. 
ClassMethod PopulateWithData(ByRef classes = "", numPop As %Integer = 10, tune As %Integer = 0, verbose As %Boolean = 0, rollbackOnError As %Boolean = 1) As %Status
{
	set st = $$$OK
	try {
		$$$TOE(st,..EnablePopulate(.classes,verbose,rollbackOnError))
		d ..PopulateClasses(.classes,numPop,tune,verbose)
	} catch ex {
		set st = ex.AsStatus()
		if verbose d $system.Status.DisplayError(st)
	}
	return st
}

/// Alternative entry point for PopulateWithData.
/// This is meant for me. I tend to return DataPopulation.Utils:Populate, 
/// but I find the method name Populate rather ambiguous.
ClassMethod Populate(ByRef classes = "", numPop As %Integer = 10, tune As %Integer = 0, verbose As %Boolean = 0, rollbackOnError As %Boolean = 1) As %Status
{
	return ..PopulateWithData(.classes, numPop, tune, verbose, rollbackOnError)
}

/// PARAMETERS:
/// 	classes is a single package, a single class, or a node array of classes passed by reference.
/// 		These classes will have %Populate added as a superclass and POPSPEC added as a property parameter where suited.
/// 	If verbose is true, error messages, compilation output, and population logs are displayed.
/// 	If rollbackOnError is true, we rollback changes to the affected classes on encountering an error. 
ClassMethod EnablePopulate(ByRef classes = "", verbose As %Boolean = 0, rollbackOnError As %Boolean = 1)
{
	set st = $$$OK
	try {
		$$$TOE(st,..AddPopulateSuper(.classes,verbose,rollbackOnError))
		$$$TOE(st,..AddPOPSPEC(.classes,verbose,rollbackOnError))
	} catch ex {
		set st = ex.AsStatus()
		if verbose d $system.Status.DisplayError(st)
	}
	return st
}

/// PARAMETERS:
/// 	classes is a single package, a single class, or a node array of classes passed by reference.
/// 		These classes will have %Populate removed from their superclasses and POPSPEC removed from all properties.
/// 	If verbose is true, error messages, compilation output, and population logs are displayed.
/// 	If rollbackOnError is true, we rollback changes to the affected classes on encountering an error. 
ClassMethod DisablePopulate(ByRef classes = "", verbose As %Boolean = 0, rollbackOnError As %Boolean = 1)
{
	set st = $$$OK
	if ($g(classes) '= "") d ..GetClasses(classes,.classes)
	if (($data(classes) '= 10) && ($data(classes) '= 11)) return st
	set clsName = "" 
	set tLevelInitial = $TLEVEL
	if rollbackOnError TSTART

	for {
		
		set clsName = $o(classes(clsName))
		if clsName = "" {
			set st = $system.OBJ.Compile(.classes,$s($g(verbose):"d",1:"-d")_"u")
			quit
		}
		set clsDef = ##class(%Dictionary.ClassDefinition).%OpenId(clsName)

		; Check if %Populate is in superclass list
		continue:('($classmethod(clsName,"%Extends","%Populate")))

	
		; Remove POPSPEC from all properties
		set key = ""
		for {
			set propDef = clsDef.Properties.GetNext(.key)
			quit:(propDef = "")
			if (propDef.Parameters.GetAt("POPSPEC"))'="" {
				d propDef.Parameters.RemoveAt("POPSPEC")
			}
			
			d propDef.%Save()
			
		}
		; Remove %Populate from superclass string list
		if (clsDef.Super [ "%Populate") { set popDelim = ",%Populate" }
		elseif (clsDef.Super [ ",%Library.Populate") { set popDelim = ",%Library.Populate" }
		set clsDef.Super = $p(clsDef.Super,popDelim,1)_$p(clsDef.Super,popDelim,*)
		

		try { 
			$$$TOE(st,clsDef.%Save())
		} catch exc {
			set st = exc.AsStatus()
			quit
		}
		
	}

	if $system.Status.IsError(st) {
		if rollbackOnError while $TLEVEL > tLevelInitial { TROLLBACK 1 }
		if verbose d $system.Status.DisplayError(st)
	}
	else {
		if rollbackOnError TCOMMIT
	}
	
	if verbose d $system.Status.DisplayError(st)
	return st
}

}
