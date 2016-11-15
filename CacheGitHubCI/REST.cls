Class CacheGitHubCI.REST Extends %CSP.REST
{

XData UrlMap
{
<Routes>
   <!-- Test method-->
   <Route Url="/Test" Method="GET" Call="Test"/>
    <Route Url="/receive/:owner/:repository/:namespace" Method="POST" Call="Receive"/>
 </Routes>
}

ClassMethod Test() As %Status
{
	Write "{""Status"": ""OK""}"
	Return $$$OK
}

ClassMethod Receive(Owner As %String, Repository As %String, Namespace = {$Namespace}) As %Status
{
	Return:'(%request.GetCgiEnv("HTTP_USER_AGENT") [ "GitHub-Hookshot") $$$ERROR($$$GeneralError,"Wrong origins")
	Set st = ##class(CacheGitHubCI.Hook).Update(Owner,Repository,Namespace)
	Return st
}

}

