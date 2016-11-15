/// Simple update task. Use CacheGitHubCI.Hook if you need more functionality.
Class CacheGitHubCI.Task Extends %SYS.Task.Definition
{

Parameter TaskName = "GitHubUpdateTask";

/// Repository URL, like https://github.com/intersystems-ru/Cache-MDX2JSON
Property GitHubURL As %String;

/// GitHub user, who has access to repository. Optional for public repositories.<br>
/// Note, that with Username/Password, you can make up to 5,000 requests per hour. 
/// For unauthenticated requests, the rate limit allows to make up to 60 requests per hour. 
/// Unauthenticated requests are associated with an IP address.<br>
/// Required, if you want to create webhooks
Property Username As %String;

/// GitHub password, corresponding to Username. Optional for public repositories.
Property Password As %String;

Property Branch As %String [ InitialExpression = "master" ];

/// Namespace, where to download and compile repository
Property Namespace As %String [ InitialExpression = {$Namespace} ];

/// If no actions are defined for the hook representing this task and this flag is TRUE,
/// we will call ##class(CacheGitHubCGCI.ActionClassTemplate).SetupHook() to setup
/// default actions automatically.
Property ConfigureActions As %Boolean [ InitialExpression = 0 ];

Property ActionClassName As %String;

Property KeepBrokenSourceOnError As %Boolean [ InitialExpression = 0 ];

Method OnTask() As %Status
{
	Set tSC = $System.Status.OK()
	Try
	{		
		If '##class(%SYS.Namespace).Exists(..Namespace) 
		{
			Set tSC = $$$ERROR($$$NamespaceUnavailable,..Namespace)
			Quit
		}
	
		Set tOwner = $ZConvert($p(..GitHubURL,"/",4),"L")
		Set tRepository = $ZConvert($p(..GitHubURL,"/",5),"L")
		Set tNamespace = $ZConvert(..Namespace,"L")
		Set tHookId=tOwner_"||"_tRepository_"||"_tNamespace
		
		If ('##class(CacheGitHubCI.Hook).%ExistsId(tHookId)) 
		{
			Set hook = ##class(CacheGitHubCI.Hook).%New(tOwner,tRepository,..Branch,..Username,..Password,tNamespace,+..KeepBrokenSourceOnError)
			Quit:$System.Status.IsError(tSC)
		}
		Else
		{
			Set hook = ##class(CacheGitHubCI.Hook).%OpenId(tHookId)
			Set hook.Branch=..Branch
			Set hook.Username=..Username
			Set hook.Password=..Password
			Set hook.KeepBrokenSourceOnError=..KeepBrokenSourceOnError
		}
		
		Set tSC = hook.%Save()
		
		If (..ConfigureActions) && (hook.PostCompile.Type="") && (hook.PreCompile.Type="") && (hook.UnitTests.Type="") && (..ActionClassName'="")
		{
			Set tSC = ##class(CacheGitHubCI.ActionClassTemplate).SetupHookObj(hook, ..ActionClassName)
			Quit:$System.Status.IsError(tSC)
		}
		
		Set tSC = ##class(CacheGitHubCI.Hook).Update(tOwner,tRepository,tNamespace)
	}
	Catch (oException)
	{
		Set tSC = oException.AsStatus()
	}
	
	Quit tSC
}

}

