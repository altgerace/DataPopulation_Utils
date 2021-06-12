Class DataPopulation.Test.Utils Extends %RegisteredObject
{

ClassMethod GetDatatypes(ByRef datatypes)
{
		set dtString = "%String,%Integer,%Date,%Binary,%Double,%Boolean,%Currency,%Float,%Numeric,%Decimal,%PosixTime,%TimeStamp,%SmallInt,%Time,%TinyInt,%BigInt"
		set dtList = $listfromstring(datatypes,",")
		
		set datatypes("%String") = ""
		set datatypes("%String","MINLEN") = ""
		set datatypes("%String","MAXLEN") = ""
		set datatypes("%Integer") = ""
		set datatypes("%Integer","MINVAL") = ""
		set datatypes("%Integer","MAXVAL") = ""
		set datatypes("%Date") = ""
		set datatypes("%Date","MINVAL") = ""
		set datatypes("%Date","MAXVAL") = ""
		set datatypes("%Binary") = ""
		set datatypes("%Binary","MINLEN") = ""
		set datatypes("%Binary","MAXLEN") = ""
		set datatypes("%Double") = ""
		set datatypes("%Double","MINVAL") = ""
		set datatypes("%Double","MAXVAL") = ""
		set datatypes("%Boolean") = ""
		set datatypes("%Currency") = ""
		set datatypes("%Currency","MINVAL") = ""
		set datatypes("%Currency","MAXVAL") = ""
		set datatypes("%Float") = ""
		set datatypes("%Float","MINVAL") = ""
		set datatypes("%Float","MAXVAL") = ""
		set datatypes("%Numeric") = ""
		set datatypes("%Numeric","MINVAL") = ""
		set datatypes("%Numeric","MAXVAL") = ""
		set datatypes("%Decimal") = ""
		set datatypes("%Decimal","MINVAL") = ""
		set datatypes("%Decimal","MAXVAL") = ""
		set datatypes("%PosixTime") = ""
		set datatypes("%PosixTime","MINVAL") = ""
		set datatypes("%PosixTime","MAXVAL") = ""
		set datatypes("%TimeStamp") = ""
		set datatypes("%TimeStamp","MINVAL") = ""
		set datatypes("%TimeStamp","MAXVAL") = ""
		set datatypes("%SmallInt") = ""	
		set datatypes("%SmallInt","MINVAL") = ""
		set datatypes("%SmallInt","MAXVAL") = ""
		set datatypes("%Time") = ""
		set datatypes("%Time","MINVAL") = ""
		set datatypes("%Time","MAXVAL") = ""
		set datatypes("%TinyInt") = ""
		set datatypes("%TinyInt","MINVAL") = ""
		set datatypes("%TinyInt","MAXVAL") = ""
		set datatypes("%BigInt") = ""
		set datatypes("%BigInt","MINVAL") = ""
		set datatypes("%BigInt","MAXVAL") = ""
}

ClassMethod CreateTestClasses() As %Status
{
	set st = $$$OK
	d ..GetDatatypes(.datatypes)

	; Create class with all datatypes
	set clsName = "DataPopulation.Test.SimpleClass"
	set cls = ##class(%Dictionary.ClassDefinition).%New(clsName)
	set cls.Super = "%Persistent"
	set st = $system.Status.AppendStatus(st,cls.%Save())
	set dt = "" 
	for {
		set dt = $o(datatypes(dt))
		quit:(dt="")
		set prop = ##class(%Dictionary.PropertyDefinition).%New(clsName_":"_$p(dt,"%",2))
		set prop.Type = dt
		if $d(datatypes(dt,"MINVAL"),minval) d prop.Parameters.SetAt(minval,"MINVAL")
		if $d(datatypes(dt,"MAXVAL"),maxval) d prop.Parameters.SetAt(maxval,"MAXVAL")
		if $d(datatypes(dt,"MINLEN"),minlen) d prop.Parameters.SetAt(minlen,"MINLEN")
		if $d(datatypes(dt,"MAXLEN"),maxlen) d prop.Parameters.SetAt(maxlen,"MAXLEN")
		set st = $system.Status.AppendStatus(st,prop.%Save())
	}
	; String with minimum length limit
	set prop = ##class(%Dictionary.PropertyDefinition).%New(clsName_":"_"MinString")
	d prop.Parameters.SetAt(minlen,datatypes("%String","MINLEN"))
	d prop.Parameters.SetAt(maxlen,datatypes("%String","MAXLEN"))
	set prop.Type = "%String"
	set st = $system.Status.AppendStatus(st,prop.%Save())
	; Collection property
	set prop = ##class(%Dictionary.PropertyDefinition).%New(clsName_":"_"CollectionList")
	set prop.Type = "%String"
	set prop.Collection = "list"
	set st = $system.Status.AppendStatus(st,prop.%Save())
	;set st = $system.Status.AppendStatus(st,prop.%Save())
	set st = $system.Status.AppendStatus(st,$system.OBJ.Compile(clsName,"-d"))
	return st
}

ClassMethod DeleteTestClasses()
{
	set st = $$$OK
	set classList = $lb("DataPopulation.Test.SimpleClass")
	set st = $system.Status.AppendStatus(st,##class(%Dictionary.ClassDefinition).%Delete(classList))
	
	return st
}

ClassMethod LoadSchema(file = "C:/InterSystems/HealthShare/mgr/HSCUSTOM/MCHS_Schema.xml") As %Status
{
	return $system.OBJ.Load(file,"-dc")
}

}
