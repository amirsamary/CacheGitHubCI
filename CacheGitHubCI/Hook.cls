/// Hook tying GitHub repository and Cache Namespace.
/// Create instance of the class, create webhook or task for updates and save the instance.
Class CacheGitHubCI.Hook Extends %Persistent
{

/// The name of the repository owner.
Property Owner As %String;

/// The name of the repository.
Property Repository As %String;

/// Namespace, where to download and compile repository
Property Namespace As %String [ InitialExpression = {$Namespace} ];

Index Index On (Owner, Repository, Namespace) [ IdKey ];

/// Repository branch, usually master. Leave empty, if you want to receive default branch.
Property Branch As %String;

/// GitHub user, who has access to repository. Optional for public repositories.<br>
/// Note, that with Username/Password, you can make up to 5,000 requests per hour. 
/// For unauthenticated requests, the rate limit allows to make up to 60 requests per hour. 
/// Unauthenticated requests are associated with an IP address.<br>
/// Required, if you want to create webhooks
Property Username As %String;

/// GitHub password, corresponding to Username. Optional for public repositories.
Property Password As %String;

/// Id of GitHub webhook. Set with CreateHook method.
Property HookId As %String;

/// Id of Cache Task. Set with CreateTask method.
Property TaskId As %String;

/// Updates history
Property Updates As list Of CacheGitHubCI.Update;

/// What to do before compiling repository
Property PreCompile As CacheGitHubCI.Action;

/// What to do after compiling repository
Property PostCompile As CacheGitHubCI.Action;

/// What to do for Unit Testing
Property UnitTests As CacheGitHubCI.Action;

/// DateTime of latest update attempt
Property LastUpdateDateTime As %TimeStamp;

/// Result of latest update attempt:<br> 
/// successful - update successful <br>
/// reverted  - update error, reverted to last successful commit 
Property LastUpdateStatus As %String;

/// Prevent reverting to the last successful commit in case of an error. It is not
/// always easy to revert. For instance, we could have run PostCompile code that 
/// could have touched the data to migrate data from one table to another. In those scenarios
/// we would want to keep everything as is to investigate what went wrong. 
/// Anyway, the default value of this property is FALSE so the old behaviour of reverting
/// is preserved for backward compatibility.
Property KeepBrokenSourceOnError As %Boolean [ InitialExpression = 0 ];

/// Set main variables, if provided.
Method %OnNew(Owner As %String, Repository As %String, Branch As %String, Username As %String, Password As %String, Namespace = {$Namespace}, KeepBrokenSourceOnError As %Boolean = 0) As %Status [ Private, ServerOnly = 1 ]
{
	Set:$d(Owner) ..Owner = $ZCVT(Owner,"l")
	Set:$d(Repository) ..Repository = Repository
	Set:$d(Namespace) ..Namespace = $ZCVT(Namespace,"l")
	Set:$d(Branch) ..Branch = Branch
	Set:$d(Username) ..Username = Username
	Set:$d(Password) ..Password = Password
	Set ..KeepBrokenSourceOnError=KeepBrokenSourceOnError
	
	Quit $$$OK
}

Method OwnerSet(value As %String) As %Status
{
    Set i%Owner=$ZCVT(value,"l")
    Quit $$$OK
}

Method RepositorySet(value As %String) As %Status
{
    Set i%Repository=$ZCVT(value,"l")
    Quit $$$OK
}

Method NamespaceSet(value As %String) As %Status
{
	Quit:'##class(%SYS.Namespace).Exists(value) $$$ERROR($$$NamespaceUnavailable,..Namespace)
    Set i%Namespace=$ZCVT(value,"l")
    Quit $$$OK
}

/// Create GitHub webhook, if we have admin access to repository.
Method CreateHook() As %Status
{
	Return:$ISVALIDNUM(..HookId) $$$ERROR($$$GeneralError, "Hook already exists")
	Set HookId = ""
	Set st = ##class(CacheGitHubCI.GitHub).CreateHook(..Owner,..Repository, ..Username, ..Password, ..Namespace, .HookId)
	Return:$$$ISERR(st) st
	Set:$ISVALIDNUM(HookId) ..HookId = HookId
	Return $ISVALIDNUM(HookId)
}

/// Delete GitHub webhook, if one exists.
Method DeleteHook() As %Status
{
	Return:(..HookId="") $$$ERROR($$$GeneralError, "Hook does not exist")
	Set st = ##class(CacheGitHubCI.GitHub).DeleteHook(..Owner,..Repository, ..Username, ..Password, ..HookId)
	Return:$$$ISERR(st) st
	Set ..HookId = ""
	Return $$$OK
}

/// Create Cache task to update every <b>min</b> minutes
Method CreateTask(min As %Integer = 60) As %Status
{
	Set task=##class(%SYS.Task).%New()
	Set task.Name = "Sync " _ ..Repository _ " into " _ ..Namespace
	Set task.NameSpace=$Namespace
	Set task.TimePeriod=0 // Daily
	Set task.TimePeriodEvery=1 // Every 1 day
	Set task.DailyFrequency=1 // Run Several times in a day
	Set task.DailyFrequencyTime=0 // Run every x minutes
	Set task.DailyIncrement=min // # of minutes between runs
	Set task.DailyStartTime = 0 // Start at 00:00:00
	Set task.DailyEndTime = 86399 // End at 23:59:59
	Set task.StartDate = $p($H,",",1) // Start today
	
	Set taskdef = ##class(CacheGitHubCI.Task).%New()
	Set taskdef.GitHubURL = "https://github.com/" _ ..Owner _ "/" _ ..Repository
	Set taskdef.Namespace = ..Namespace
	Do task.AssignSettings(taskdef)
	Set task.TaskClass=$classname(taskdef)
	
	Set st = task.%Save()
	Return:$$$ISERR(st) st
	Set ..TaskId = task.%Id()
	Return ##class(%SYS.Task).RunNow(..TaskId)
}

/// Delete update task
Method DeleteTask() As %Status
{
	Set st = ##class(%SYS.Task).%DeleteId(..TaskId)
	Return:$$$ISERR(st) st
	Set ..TaskId = ""
	Return $$$OK
}

/// Check repository and update local namespace
ClassMethod Update(Owner As %String, Repository As %String, Namespace = {$Namespace}) As %Status
{
 	#dim hook As CacheGitHubCI.Hook
 	Set tSC = $System.Status.OK()
 	Try
 	{
		If '##class(%SYS.Namespace).Exists(Namespace) 
		{
			Set tSC = $$$ERROR($$$NamespaceUnavailable,Namespace)
			Quit
		}
	
	
		Set hook = ..GetObject(Owner,Repository,Namespace)
		
		Set lastCommit = ##class(%ZEN.proxyObject).%New()
		Set tSC = ##class(CacheGitHubCI.GitHub).GetLastCommit(hook.Owner,hook.Repository,hook.Branch,hook.Username,hook.Password,.lastCommit)
		Quit:$$$ISERR(tSC)
	
		If ((hook.Updates.Count()>0) && (lastCommit.sha = hook.Updates.GetPrevious("").Commit)) 
		{	
			// Our last commit is the same as the repository's last commit. We are up to date!
			// Let's just update the hook to indicate the last time we checked:
			Set hook.LastUpdateDateTime = $ZDT($NOW(),3,1,2)
			Set tSC = hook.%Save()
			Quit
		}
		
		//If we are here, that is because there are commits on GitHub that we don't have downloaded yet.

		Set update = ##class(CacheGitHubCI.Update).%New(hook.%Id())
		Set update.Commit = lastCommit.sha
		Set update.Author = lastCommit.author.login
		Set update.URL = lastCommit.url
		
		// Let's run the PreCompile code before we start downloading and compiling classes from github:
		Set update.PreCompileStatus = hook.PreCompile.Execute()
		If ('hook.KeepBrokenSourceOnError) || ($System.Status.IsOK(update.PreCompileStatus))
		{
			// If PreCompileStatus is OK or, if it isn't but we don't care, we can go on and/
			// start downloading stuff from github. The Update() method downloads and compiles everything:
			Set update.CompileStatus = ##class(CacheGitHubCI.GitHub).Update(hook.Owner,hook.Repository,hook.Branch,hook.Username,hook.Password,hook.Namespace)
		}
		
		If ('hook.KeepBrokenSourceOnError) || ($System.Status.IsOK(update.CompileStatus))
		{
			// If CompileStatus is OK or, if it isn't but we don't care, we can execute PostCompile
			Set update.PostCompileStatus = hook.PostCompile.Execute()
		}
		
		If ('hook.KeepBrokenSourceOnError) || ($System.Status.IsOK(update.PostCompileStatus))
		{
			// If PostCompileStatus is OK or, if it isn't but we don't care, we can execute UnitTests
			Set update.UnitTestsStatus = hook.UnitTests.Execute()
		}
				
		Set tSC = hook.AddHookUpdate(update)
		Quit:$System.Status.IsError(tSC)
		
		Set tSC = $$$ADDSC($$$ADDSC($$$ADDSC(update.PreCompileStatus,update.CompileStatus),update.PostCompileStatus),update.UnitTestsStatus)
		If $$$ISERR(tSC) && ('hook.KeepBrokenSourceOnError)
		{
			//This is the old behaviour of revert to the last succesful commit.
			Set hook.LastUpdateStatus = "Reverted"
			Set successcommit = ##class(CacheGitHubCI.Update).GetLastSuccessfulCommit(Owner,Repository,Namespace) 
			do hook.PreCompile.Execute()
			do ##class(CacheGitHubCI.GitHub).Update(hook.Owner,hook.Repository,successcommit,hook.Username,hook.Password,hook.Namespace)
			do hook.PostCompile.Execute()
			do hook.UnitTests.Execute()
		} 
		ElseIf $$$ISERR(tSC) && (hook.KeepBrokenSourceOnError)
		{
			// This is the new alternate behaviour to simply leave the mess so someone can investigate
			// what went wrong.
			Set hook.LastUpdateStatus = "Unsuccessful and unreverted"
		}
		Else 
		{
			Set hook.LastUpdateStatus = "Successful"
		}
	
		Set hook.LastUpdateDateTime = $ZDT($NOW(),3,1,2)
		
		Set tSC = hook.%Save()
		Quit:$System.Status.IsError(tSC)
		
		JOB ##class(CacheGitHubCI.Cube).BuildCube()
	}
	Catch (oException)
	{
		Set tSC = oException.AsStatus()
	}
	
	Return tSC
}

Method AddHookUpdate(pUpdate As CacheGitHubCI.Update) As %Status
{
	Do ..Updates.Insert(pUpdate)
	Set ..LastUpdateDateTime = $ZDT($NOW(),3,1,2)
	Quit ..%Save()
}

ClassMethod GetObject(Owner As %String, Repository As %String, Namespace = {$Namespace}) As CacheGitHubCI.Hook
{
	Set Owner = $ZCVT(Owner,"l")
	Set Repository = $ZCVT(Repository,"l")
	Set Namespace = $ZCVT(Namespace,"l")

	If (##class(CacheGitHubCI.Hook).%ExistsId(Owner_"||"_Repository_"||"_Namespace)) {
		Set hook = ##class(CacheGitHubCI.Hook).%OpenId(Owner_"||"_Repository_"||"_Namespace)
	} Else {
		Set hook=##class(CacheGitHubCI.Hook).%New()     
		Set hook.Namespace = Namespace                       
		Set hook.Owner = Owner            
		Set hook.Repository = Repository      
		Set hook.Branch = "master"                    
		Do hook.%Save()
	}
	Return hook
}

Storage Default
{
<Data name="HookDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Branch</Value>
</Value>
<Value name="3">
<Value>Username</Value>
</Value>
<Value name="4">
<Value>Password</Value>
</Value>
<Value name="5">
<Value>HookId</Value>
</Value>
<Value name="6">
<Value>Owner</Value>
</Value>
<Value name="7">
<Value>Repository</Value>
</Value>
<Value name="8">
<Value>Namespace</Value>
</Value>
<Value name="9">
<Value>Updates</Value>
</Value>
<Value name="10">
<Value>TaskId</Value>
</Value>
<Value name="11">
<Value>PreCompile</Value>
</Value>
<Value name="12">
<Value>PostCompile</Value>
</Value>
<Value name="13">
<Value>UnitTests</Value>
</Value>
<Value name="14">
<Value>PreCompileStatus</Value>
</Value>
<Value name="15">
<Value>PostCompileStatus</Value>
</Value>
<Value name="16">
<Value>UnitTestsStatus</Value>
</Value>
<Value name="17">
<Value>LastUpdateDateTime</Value>
</Value>
<Value name="18">
<Value>LastUpdateStatus</Value>
</Value>
<Value name="19">
<Value>KeepBrokenSourceOnError</Value>
</Value>
</Data>
<DataLocation>^CacheGitHubCI.HookD</DataLocation>
<DefaultData>HookDefaultData</DefaultData>
<IdLocation>^CacheGitHubCI.HookD</IdLocation>
<IndexLocation>^CacheGitHubCI.HookI</IndexLocation>
<StreamLocation>^CacheGitHubCI.HookS</StreamLocation>
<Type>%Library.CacheStorage</Type>
}

}

