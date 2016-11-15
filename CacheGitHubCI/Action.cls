Class CacheGitHubCI.Action Extends %SerialObject
{

/// Type of performed action.
Property Type As %String(VALUELIST = ",classmethod,code");

/// Parameters for performed action.<br>
/// For classmethod Type: classmethod,classname,arg1,...,argN<br>
/// For code Type: COS code. Recommended structure: Set st=##class(Some.Class).DoSomeThing(Args) Throw:('st) ##class(%Exception.StatusException).CreateFromStatus(st)"<br>
Property Params As %String;

/// Namespace, to execute action.
Property Namespace As %String [ InitialExpression = {$Namespace} ];

/// Executes Action specified.
Method Execute() As %Status
{
	Return:..Type="" $$$OK
	
	Set Namespace = $Namespace
	zn ..Namespace
	
	If (..Type="classmethod") {
		Set st = ..ExecuteClassMethod()
	} ElseIf (..Type="code") {
		Set st = ..ExecuteCode()
	}
	
	Zn Namespace
	Return st
}

Method ExecuteClassMethod() As %Status [ Internal ]
{
	Set class = $p(..Params,",",1)
	Set method = $p(..Params,",",2)
	Set args = $l(..Params,",") - 2
	For i=3:1:$l(..Params,",") {
		Set args(i-2)=$p(..Params,",",i)
	}
	Return $classmethod(class,method,args...)
}

/// Copied from %SYS.Task.RunLegacyTask
Method ExecuteCode() [ Internal, ProcedureBlock = 0 ]
{
	Set $ZT="Error"
	Set Status=$$$OK
	X ..Params
	Quit $g(Status,$$$OK)
Error	;
	Set $ZT=""
	Quit $$$ERROR($$$GeneralError,$ze)
}

/// This callback method is invoked by the <METHOD>%ValidateObject</METHOD> method to 
/// provide notification that the current object is being validated.
/// 
/// <P>If this method returns an error then <METHOD>%ValidateObject</METHOD> will fail.
Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
	If (..Type="classmethod"){
		Set length = $l(..Params,",")
		Return:length<2 $$$ERROR($$$GeneralError,"Params property must be a: classmethod,classname,arg1,...,argN")
	}
	
	Return:'##class(%SYS.Namespace).Exists(..Namespace) $$$ERROR($$$NamespaceUnavailable,..Namespace)
	Return $$$OK
}

Storage Default
{
<Data name="ActionDefaultData">
<Subscript>"1"</Subscript>
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<Data name="ActionState">
<Value name="1">
<Value>Type</Value>
</Value>
<Value name="2">
<Value>Params</Value>
</Value>
<Value name="3">
<Value>Namespace</Value>
</Value>
</Data>
<DataLocation>^CacheGitHubCI.ActionD</DataLocation>
<DefaultData>ActionDefaultData</DefaultData>
<IdLocation>^CacheGitHubCI.ActionD</IdLocation>
<IndexLocation>^CacheGitHubCI.ActionI</IndexLocation>
<State>ActionState</State>
<StreamLocation>^CacheGitHubCI.ActionS</StreamLocation>
<Type>%Library.CacheSerialState</Type>
}

}

