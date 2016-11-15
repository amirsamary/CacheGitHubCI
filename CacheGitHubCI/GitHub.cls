Class CacheGitHubCI.GitHub Extends (%RegisteredObject, CacheGitHubCI.UDL)
{

ClassMethod GetLocalIP() As %String
{
	Return:($d(^CacheGitHubCI("IP"))) ^CacheGitHubCI("IP")
	Return $SYSTEM.INetInfo.HostNameToAddr($SYSTEM.INetInfo.LocalHostName()) // unreliable
}

ClassMethod CreateRequest(Username As %String, Password As %String) As %Net.HttpRequest
{
	Set namespace = $Namespace
 	Set SSLConfig = "GitHub"

 	Zn "%SYS"
 	Do:'##class(Security.SSLConfigs).Exists(SSLConfig) ##class(Security.SSLConfigs).Create(SSLConfig)
 	Zn namespace

 	Set req=##class(%Net.HttpRequest).%New()
 	Set req.Https=1
	Set req.SSLConfiguration=SSLConfig
	Set req.Server="api.github.com"
	Do req.SetHeader("Accept","application/vnd.github.v3+json") 			// we want 3rd version of api

	If ($d(Username) && $d(Password) && (Username'="") && (Password'="")) {	// supply Username and Passwor, if both are provided. GitHub accept Basic Auth
		Set req.Username = Username											// https://developer.github.com/v3/auth/
	 	Set req.Password = Password
	}

	Return req
}

ClassMethod CreateHook(Owner As %String, Repository As %String, Username As %String = "", Password As %String = "", Namespace = {$Namespace}, Output HookId) As %Status
{
	#dim req As %Net.HttpRequest
	Set req = ..CreateRequest(Username, Password)
	Set req.Location = "repos/" _ Owner _ "/" _ Repository _ "/hooks"

	Set hook = ##class(%ZEN.proxyObject).%New()
	Set hook.name = "web"
	//set hook.active = 1 // can't supply js true/false. True by default
	Set hook.events = ##class(%ListOfDataTypes).%New()
	Do hook.events.Insert("push")
	Set hook.config = ##class(%ZEN.proxyObject).%New()
	Set hook.config.url = "http://" _..GetLocalIP() _"/cgci/receive/"_ Owner _ "/" _ Repository _"/" _ Namespace
	Set hook.config."content_type" = "json"
	Set hook.config."insecure_ssl" = 1
	Set st = ##class(%ZEN.Auxiliary.jsonProvider).%WriteJSONStreamFromObject(req.EntityBody,hook)
	Set st = req.Post()

	Return:$$$ISERR(st) st
	Return:(req.HttpResponse.StatusCode = 404) $$$ERROR($$$GeneralError,"Repository doesn't exist OR you don't have access")
	Return:((req.HttpResponse.StatusCode = 403) && (req.HttpResponse.GetHeader("X-RATELIMIT-REMAINING")=0)) $$$ERROR($$$GeneralError,"API rate limit exceeded. Try logging in.")
 	Return:(req.HttpResponse.StatusCode '= 201) $$$ERROR($$$GeneralError,"Received " _ req.HttpResponse.StatusCode _ " expected 200")

 	Set st = ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(req.HttpResponse.Data,,.obj,1)
 	Set HookId = obj.id

	Return st
}

ClassMethod DeleteHook(Owner As %String, Repository As %String, Username As %String = "", Password As %String = "", HookId As %Integer) As %Status
{
	#dim req As %Net.HttpRequest
	Set req = ..CreateRequest(Username, Password)
	Set req.Location = "repos/" _ Owner _ "/" _ Repository _ "/hooks/" _ HookId

	Set st = req.Send("DELETE","")

	Return:$$$ISERR(st) st
	Return:(req.HttpResponse.StatusCode = 404) $$$ERROR($$$GeneralError,"Repository doesn't exist OR you don't have access")
	Return:((req.HttpResponse.StatusCode = 403) && (req.HttpResponse.GetHeader("X-RATELIMIT-REMAINING")=0)) $$$ERROR($$$GeneralError,"API rate limit exceeded. Try logging in.")
 	Return:(req.HttpResponse.StatusCode '= 204) $$$ERROR($$$GeneralError,"Received " _ req.HttpResponse.StatusCode _ " expected 204")

	Return $$$OK
}

ClassMethod GetHooks(Owner As %String, Repository As %String, Username As %String = "", Password As %String = "", Namespace = {$Namespace}, Output Hooks) As %Status
{
	Set req = ..CreateRequest(Username, Password)
	Set req.Location = "repos/" _ Owner _ "/" _ Repository _ "/hooks"

	Set st = req.Get()
	Return:$$$ISERR(st) st
	Return:(req.HttpResponse.StatusCode = 404) $$$ERROR($$$GeneralError,"Repository doesn't exist OR you don't have access")
	Return:((req.HttpResponse.StatusCode = 403) && (req.HttpResponse.GetHeader("X-RATELIMIT-REMAINING")=0)) $$$ERROR($$$GeneralError,"API rate limit exceeded. Try logging in.")
 	Return:(req.HttpResponse.StatusCode '= 200) $$$ERROR($$$GeneralError,"Received " _ req.HttpResponse.StatusCode _ " expected 200")

 	#dim objects As List of %ZEN.proxyObject
	Set st = ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(req.HttpResponse.Data,,.Hooks,1)
	Return st
}

ClassMethod GetLastCommit(Owner As %String, Repository As %String, Branch As %String = "master", Username As %String = "", Password As %String = "", Output Commit As %ZEN.proxyObject) As %Status
{
	kill Commit
	Set req = ..CreateRequest(Username, Password)
	Set:(Branch="") Branch="HEAD" // Branch does not automatically elevates to master
	Set req.Location = "repos/" _ Owner _ "/" _ Repository _ "/commits/" _ Branch

	Set st = req.Get()
	Return:$$$ISERR(st) st
	Return:(req.HttpResponse.StatusCode = 404) $$$ERROR($$$GeneralError,"Repository doesn't exist OR you don't have access")
	Return:((req.HttpResponse.StatusCode = 403) && (req.HttpResponse.GetHeader("X-RATELIMIT-REMAINING")=0)) $$$ERROR($$$GeneralError,"API rate limit exceeded. Try logging in.")
 	Return:(req.HttpResponse.StatusCode '= 200) $$$ERROR($$$GeneralError,"Received " _ req.HttpResponse.StatusCode _ " expected 200")

	Set st = ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(req.HttpResponse.Data,,.Commit,1)
	Return st
}

/// Downloads and compiles GitHub repository.<br>
/// <b>Owner</b> - The name of the repository owner.<br>
/// <b>Repository</b> - The name of the repository.<br>
/// <b>Branch</b> - The name of the commit/branch/tag. If skipped the repository?s default branch (usually master) would be used.<br>
/// <b>Username</b> - GitHub user, who has access to repository. Optional for public repositories.<br>
/// <b>Password</b> - GitHub password, corresponding to Username. Optional for public repositories.<br>
/// Note, that with Username, you can make up to 5,000 requests per hour.
/// For unauthenticated requests, the rate limit allows to make up to 60 requests per hour.
/// Unauthenticated requests are associated with an IP address.<br>
/// <b>Namespace</b> - Namespace, where to download and compile repository.<br>
/// 
/// For example in the repository: https://github.com/intersystems-ru/Cache-MDX2JSON<br>
/// Owner - intersystems-ru, Repository - Cache-MDX2JSON.<br> 
ClassMethod Update(Owner As %String, Repository As %String, Branch As %String = "", Username As %String = "", Password As %String = "", Namespace = {$Namespace}) As %Status
{
	#dim req As %Net.HttpRequest
	Set tSC = $System.Status.OK()
	Try
	{
		Set tCGCINamespace = $Namespace
		
		Set req = ..CreateRequest(Username, Password)
		Set req.Location = "repos/" _ Owner _ "/" _ Repository _ "/contents" 	// as described in https://developer.github.com/v3/repos/

		Set links = ##class(%ListOfDataTypes).%New()
		Set tSC = ..ProcessDirectory("",.req,Branch,Namespace,.links)
		Quit:$System.Status.IsError(tSC)

		Set tSC = ..DownloadFiles(links,req,.list,Namespace)
		Quit:$System.Status.IsError(tSC)
		
		Set bDBReadWrite = ..CanWriteOnCurrentNS()
		If bDBReadWrite
		{
			Zn Namespace

			Set tSC = $system.OBJ.CompileList(.list,"cuk /checkuptodate=expandedonly")
		}
	}
	Catch (oException)
	{
		Set tSC = oException.AsStatus()
	}
	
	ZN tCGCINamespace
	Quit tSC
}

/// Process one directory of GitHub repository. Recursive.<br>
/// <b>Path</b> -Internal repository path. Root is empty string<br>
/// <b>Request</b> - Authenticated/Set %Net.HttpRequest object.<br>
/// <b>Links</b> - List of links to raw files (which satisfy <b>IsCacheFile</b> conditions) from repository.<br>
ClassMethod ProcessDirectory(Path As %String = "", Request As %Net.HttpRequest, Branch As %String = "", pTargetNamespace As %String, ByRef Links As %ListOfDataTypes) As %Status
{
	Set location = Request.Location
	Set Request.Location = Request.Location _ Path
	Do:(Branch'="") Request.SetParam("ref",Branch)

	Set st = Request.Get()

	Return:$$$ISERR(st) st
	Return:(Request.HttpResponse.StatusCode = 404) $$$ERROR($$$GeneralError,"Repository doesn't exist OR you don't have access")
	Return:((Request.HttpResponse.StatusCode = 403) && (Request.HttpResponse.GetHeader("X-RATELIMIT-REMAINING")=0)) $$$ERROR($$$GeneralError,"API rate limit exceeded. Try logging in.")
 	Return:(Request.HttpResponse.StatusCode '= 200) $$$ERROR($$$GeneralError,"Received " _ Request.HttpResponse.StatusCode _ " expected 200")

 	#dim objects As List of %ZEN.proxyObject
 	#dim obj As %ZEN.proxyObject
	Set st = ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(Request.HttpResponse.Data,,.objects,1)
	Return:$$$ISERR(st) st

	Write !,Request.Location
	For i = 1:1:objects.Count()
	{
		Set obj = objects.GetAt(i)
		If (obj.type = "dir")
		{
			Set st = ..ProcessDirectory("/"_obj.name,Request,Branch,pTargetNamespace,.Links)
			Return:$$$ISERR(st) st
		}
		ElseIf (obj.type = "file")
		{
			//Do:..IsCacheFile(obj) Links.Insert(obj."download_url")
			Set bIsCacheFile = ..IsCacheFile(obj)
			If ..FileHasChanged(pTargetNamespace, obj.path, obj.sha)
			{
				Write "."
				Do Links.Insert($LB(obj."download_url",bIsCacheFile,obj.path, obj.sha))
			}
		}
		Else
		{
			// obj.type = "symlink" or obj.type = "submodule"
		}
	}
	Set Request.Location = location // to keep track of where in the repository tree we are
	Return $$$OK
}

/// This method is used by ProcessDirectory() to determine if a file has
/// changed since the last download. 
/// pIsCacheFile will allow us to know if we can download this file or not. 
ClassMethod FileHasChanged(pTargetNamespace As %String, pFullFileName As %String, pFileHash As %String)
{
	Set tFullFileNameHash = $System.Encryption.SHA1Hash(pFullFileName)
	If $Get(^CGCIFileHash(pTargetNamespace,tFullFileNameHash))=pFileHash Return 0

	Return 1
}

/// This method is called from DownloadFiles() to register a file that has just been
/// downloaded from the server. The idea is that on the next synchronization with GitHub
/// ProcessDirectory() will only queue for downloading files that are not registered (new files)
/// or are registered but are different from the last download (changed files).
ClassMethod RegisterFileChanged(pTargetNamespace As %String, tFileFullName As %String, tFileHash As %String)
{
	Set tFullFileNameHash = $System.Encryption.SHA1Hash(tFileFullName)
	Set ^CGCIFileHash(pTargetNamespace,tFullFileNameHash)=tFileHash
}

/// Check that incoming file is the one you need.
ClassMethod IsCacheFile(File As %ZEN.proxyObject) As %Boolean
{
	Set extensions = ",xml,cls,csp,csr,mac,int,bas,inc,gbl,prj,obj,pkg,gof,dfi,pivot,dashboard,html,css,js,ts,scss,"
	Return:($L(File.name,".")=1) 0 //no extension
	Set File.Extension = $P(File.name,".",$L(File.name,"."))
	Return $F(extensions,","_$ZCVT(File.Extension,"l")_",")
}

/// Download list of files on https://raw.githubusercontent.com/ server.<br>
/// <b>Links</b> - List of links to raw files.<br>
/// <b>Request</b> - Authenticated/Set %Net.HttpRequest object.<br>
/// <b>loadedlist</b> - Returns an array of the items loaded. 
ClassMethod DownloadFiles(Links As %ListOfDataTypes, Request As %Net.HttpRequest, Output Items, pTargetNamespace As %String = "CGCI") As %Status
{
	Kill Items
	Set Request.Server = "raw.githubusercontent.com"
	Set st = $$$OK
	Try
	{
		Set tNS = $Namespace
		
		For i = 1:1:Links.Count()
		{
			Set link = $ListGet(Links.GetAt(i),1)
			Set bIsCacheFile = $ListGet(Links.GetAt(i),2)
			Set tFileFullName = $ListGet(Links.GetAt(i),3)
			Set tFileHash = $ListGet(Links.GetAt(i),4)

			Set streq = Request.Get($e(link,35,*)) // Remove "https://raw.githubusercontent.com/" from URL.
			If $$$ISERR(streq)
			{
				Set st=$$$ADDSC(st, streq)
				Continue
			}

			Set binarystream = Request.HttpResponse.Data

			Do binarystream.Rewind() // just in case

			Set characterStream=##class(%GlobalCharacterStream).%New() //translating binary stream into character stream
			Set stTranslate=$$$OK
			Try
			{
				While 'binarystream.AtEnd
				{
					//Use eol to prevent breaking lines larger than 32Kb
					Set line=binarystream.ReadLine(, .stTranslate, .eol)
					Quit:$System.Status.IsError(stTranslate)

					If eol
					{
						Set stTranslate=characterStream.WriteLine(line)
					}
					Else
					{
						Set stTranslate=characterStream.Write(line)
					}
					Quit:$System.Status.IsError(stTranslate)
				}
				Quit:$System.Status.IsError(stTranslate)

				Do characterStream.Rewind()
			}
			Catch (oTranslateStreamException)
			{
				Set stTranslate=oTranslateStreamException.AsStatus()
			}

			If $System.Status.IsError(stTranslate)
			{
				//Could not convert binary stream to character stream
				//It is probably a binary file anyway
				Set characterStream=""
				Set st=$$$ADDSC(st, stTranslate)
			}

			Do binarystream.Rewind()

			Set stload = $$$OK

			set items = ""
			ZN pTargetNamespace
			If ('$IsObject(characterStream)) || (..IsUDLFile(characterStream))
			{
				// LoadUDDLFile is mirror aware now. If we are on a secondary node of a mirror, that won't allow us to
				// write into the database and the file on the link is a Caché file that is loaded
				// inside the database (MAC, INT, CLS, DFI), it will simply skip it and return OK. If it is a HTML, JS,
				// PNG, etc. file, that can sit outside the database, the file will be generated as usual. If it is a CSP file
				// the file will be generated outside the database as usual but the Update() method won't be loading them into
				// the database. That will be done by the primary mirror member when it downloads the file from github. 
				Set stload = ..LoadUDLFile(characterStream, binarystream, link, .items)
			}
			ElseIf bIsCacheFile
			{
				//Unfortunately LoadStream will always verify if the database can be written and refrain
				//to generate CSP, Js, Html, etc. files... So, working with XML will remain incompatible with mirroring.
				Set stload = $system.OBJ.LoadStream(characterStream,"",.error,.items,,,,"UTF8")
			}
			
			ZN tNS
			
	 		If $$$ISERR(stload)
	 		{
		 		Set st=$$$ADDSC(st, stload)
		 		Continue
	 		}
	 		Else
	 		{
		 		Do ..RegisterFileChanged(pTargetNamespace, tFileFullName, tFileHash)
	 		}
	 		Merge Items = items  // Does not overwrite existing array keys: Items(itemname)=""
		}

		Set Request.Server="api.github.com"
	}
	Catch (oException)
	{
		Set st = oException.AsStatus()
	}
	
	ZN tNS
	
	Quit st
}

/// This is a helper method only used when debugging code. It should not
/// be called from anywhere on production code.
ClassMethod Debug(pStringOrStream)
{
	Quit:pStringOrStream=""
	If '$IsObject(pStringOrStream)
	{
		Set ^CGCIDebug($I(^CGCIDebug))=pStringOrStream
	}
	Else
	{
		Do pStringOrStream.Rewind()
		Set ^CGCIDebug($I(^CGCIDebug))=pStringOrStream.Read(32000)
		Do pStringOrStream.Rewind()
	}
}

}

