/// This is a suggestion of a class from which a system that is using CGCI could inhirit from
/// to define actions that could be called by CGCI during the Update() action.
/// Of course that the update hook must be edited to call these class methods on the correct 
/// namespace.
/// 
/// If you already have a hook defined and wants to configure it to delegate the action calls to
/// a class that inherit from this one on the namespace where the update is being applyed, just
/// call the method SetupHookObj(pHook) or SetupHook(pHookId).
Class CacheGitHubCI.ActionClassTemplate Extends %RegisteredObject
{

ClassMethod OnPreCompile() As %Status
{
	Quit $$$OK
}

ClassMethod OnPostCompile() As %Status
{
	Quit $$$OK
}

ClassMethod OnUnitTests() As %Status
{
	Quit $$$OK
}

ClassMethod SetupHook(pHookId As %String, pClassName As %String) As %Status
{
	Set oHook = ##class(Hook).%OpenId(pHookId)
	Quit ..SetupHookObj(oHook, pClassName)
}

/// Sets up an existing hook to call actions on the namespace where the code is
/// being deployed. The class pClassName must be defined on the namespace where
/// the code is being deployed and must inherit from this class (through package mapping)
/// or simply have the expected methods (OnPreCompile, OnPostCompile and OnUnitTests).
ClassMethod SetupHookObj(pHook As Hook, pClassName As %String) As %Status
{
	Set pHook.PreCompile.Type="classmethod"
	Set pHook.PreCompile.Namespace=pHook.Namespace
	Set pHook.PreCompile.Params=pClassName_",OnPreCompile"
	
	Set pHook.PostCompile.Type="classmethod"
	Set pHook.PostCompile.Namespace=pHook.Namespace
	Set pHook.PostCompile.Params=pClassName_",OnPostCompile"
	
	Set pHook.UnitTests.Type="classmethod"
	Set pHook.UnitTests.Namespace=pHook.Namespace
	Set pHook.UnitTests.Params=pClassName_",OnUnitTests"
	
	Quit pHook.%Save()
}

}

