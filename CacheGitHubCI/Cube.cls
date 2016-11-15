/// Cube for Continuous Integration for InterSystems Caché and GitHub. See at https://github.com/intersystems-ru/CacheGitHubCI
Class CacheGitHubCI.Cube Extends %DeepSee.CubeDefinition [ DependsOn = CacheGitHubCI.Hook, ProcedureBlock ]
{

Parameter DOMAIN;

/// Cube definition from Architect.
XData Cube [ XMLNamespace = "http://www.intersystems.com/deepsee" ]
{
<cube xmlns="http://www.intersystems.com/deepsee" name="CacheGitHubCICube" displayName="CacheGitHubCICube" description="Cube for Continuous Integration for InterSystems Caché and GitHub. See at https://github.com/intersystems-ru/CacheGitHubCI" disabled="false" abstract="false" sourceClass="CacheGitHubCI.Hook" countMeasureName="%COUNT" bucketSize="8" bitmapChunkInMemory="false" precompute="0">
  <dimension name="Owner" disabled="false" hasAll="false" allCaption="All Owner" allDisplayName="Owner" type="data" hidden="false" showHierarchies="default">
    <hierarchy name="H1" disabled="false">
      <level sourceProperty="Owner" name="Owner" disabled="false" list="false" useDisplayValue="true" useAsFilter="true">
      </level>
    </hierarchy>
  </dimension>
  <dimension name="Namespace" disabled="false" hasAll="false" allCaption="All Namespace" allDisplayName="Namespace" type="data" hidden="false" showHierarchies="default">
    <hierarchy name="H1" disabled="false">
      <level sourceProperty="Namespace" name="Namespace" disabled="false" list="false" useDisplayValue="true" useAsFilter="true">
      </level>
    </hierarchy>
  </dimension>
  <dimension name="LastUpdateStatus" disabled="false" hasAll="false" allCaption="All LastUpdateStatus" allDisplayName="LastUpdateStatus" type="data" hidden="false" showHierarchies="default">
    <hierarchy name="H1" disabled="false">
      <level sourceProperty="LastUpdateStatus" name="LastUpdateStatus" disabled="false" list="false" useDisplayValue="true" useAsFilter="true">
      </level>
    </hierarchy>
  </dimension>
  <dimension name="Branch" disabled="false" hasAll="false" allCaption="All Branch" allDisplayName="Branch" type="data" hidden="false" showHierarchies="default">
    <hierarchy name="H1" disabled="false">
      <level sourceProperty="Branch" name="Branch" disabled="false" list="false" useDisplayValue="true" useAsFilter="true">
      </level>
    </hierarchy>
  </dimension>
  <dimension name="Repository" disabled="false" hasAll="false" allCaption="All Repository" allDisplayName="Repository" type="data" hidden="false" showHierarchies="default">
    <hierarchy name="H1" disabled="false">
      <level sourceProperty="Repository" name="Repository" disabled="false" list="false" useDisplayValue="true" useAsFilter="true">
      </level>
    </hierarchy>
  </dimension>
  <dimension name="LastUpdateDateTime" disabled="false" hasAll="false" allCaption="All LastUpdateDateTime" allDisplayName="LastUpdateDateTime" sourceProperty="LastUpdateDateTime" type="time" iKnowType="entity" hidden="false" showHierarchies="default">
    <hierarchy name="H1" disabled="false">
      <level name="LastUpdateDateTime" disabled="false" timeFunction="DayMonthYear" list="false" useDisplayValue="true" useAsFilter="true">
      </level>
    </hierarchy>
  </dimension>
  <measure sourceProperty="LastUpdateDateTime" name="LastUpdateAgeDays" disabled="false" aggregate="MAX" type="age" hidden="false" searchable="false"></measure>
  <measure sourceProperty="LastUpdateDateTime" name="LastUpdateDate" disabled="false" aggregate="MAX" type="date" hidden="false" searchable="false"></measure>
  <measure sourceExpression="$s(%source.LastUpdateStatus=&quot;Successful&quot;:1,1:0)" name="LastUpdateSuccess" disabled="false" aggregate="MAX" type="integer" hidden="false" searchable="false"></measure>
  <listing name="UpdatesHistory" disabled="false" listingType="table" fieldList="LastUpdateStatus" sql="SELECT Author, CacheGitHubCI.DisplayStatus(PreCompileStatus) As PreCompileStatus, CacheGitHubCI.DisplayStatus(CompileStatus) As CompileStatus,  CacheGitHubCI.DisplayStatus(PostCompileStatus) AS PostCompileStatus,  CacheGitHubCI.DisplayStatus(UnitTestsStatus) As UnitTestsStatus, DateTimeStart, DateTimeEnd, Length, &quot;Commit&quot; FROM CacheGitHubCI.&quot;Update&quot;, $$$SOURCE WHERE $$$RESTRICT AND source.%ID=Hook ORDER BY CacheGitHubCI.&quot;Update&quot;.ID DESC"></listing>
</cube>
}

/// Build cube after <i>Delay</i> seconds.
ClassMethod BuildCube(Delay As %Integer = 10)
{
	Hang Delay
	Do ##class(%DeepSee.Utils).%BuildCube("CacheGitHubCICube",1,0)
}

}

