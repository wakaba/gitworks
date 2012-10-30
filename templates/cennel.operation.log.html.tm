<!DOCTYPE html>
<html t:params=$operation>
<t:call x="use URL::PercentEncode qw(percent_encode_c)">
<title t:parse>Cennel operation log - <t:text value="$operation->{operation}->{id}"></title>
<t:call x="
sub _datetime ($) {
    my @time = gmtime $_[0];
    return sprintf '%04d-%02d-%02dT%02d:%02d:%02d-00:00',
        $time[5] + 1900, $time[4] + 1, $time[3], $time[2], $time[1], $time[0];
}
">

<h1>Cennel operation log - <code><t:text value="$operation->{operation}->{id}"></code></h1>

<dl>
  <dt>Operation ID
  <dd><a pl:href="'/cennel/logs/' . $operation->{operation}->{id}"><code><t:text value="$operation->{operation}->{id}"></code></a>

  <dt>Repository
  <dd><a pl:href="'/repos?repository_url=' . percent_encode_c $operation->{repository}->{url}"><t:text value="$operation->{repository}->{url}"></a>
  <dd><a pl:href="'/repos/commits?repository_url=' . (percent_encode_c $operation->{repository}->{url}) . '&sha=' . percent_encode_c $operation->{repository}->{sha}"><t:text value="substr $operation->{repository}->{sha}, 0, 10"></a>
  (<a pl:href="'/repos/commits?repository_url=' . (percent_encode_c $operation->{repository}->{url}) . '&sha=' . percent_encode_c $operation->{repository}->{branch}"><t:text value="$operation->{repository}->{branch}"></a>)

  <dt>Role
  <dd>@<t:text value="$operation->{role}->{name}">

  <dt>Task
  <dd><t:text value="$operation->{task}->{name}">

  <dt>Status
  <dd><code><t:text value="$operation->{operation}->{status}"></code>
  (<t:text value="
    {
      1 => 'Initial',
      2 => 'Started',
      3 => 'Failed',
      4 => 'Succeeded',
      5 => 'Precondition failed',
      6 => 'Skipped',
      7 => 'Reverted',
    }->{$operation->{operation}->{status}} || $operation->{operation}->{status}
  ">)

  <dt>Start
  <dd>
    <t:if x="$operation->{operation}->{start_timestamp}">
      <time><t:text value="_datetime $operation->{operation}->{start_timestamp}"></time>
    <t:else>
      -
    </t:if>

  <dt>End
  <dd>
    <t:if x="$operation->{operation}->{end_timestamp}">
      <time><t:text value="_datetime $operation->{operation}->{end_timestamp}"></time>
    <t:else>
      -
    </t:if>
</dl>

<nav>
  <ul>
    <li><a href=#global-log>Log</a>
    <t:for as=$unit x="[values %{$operation->{units}}]">
      <li><a pl:href="'#unit-' . $unit->{id}"><t:text value="$unit->{host}->{name}"></a>
    </t:for>
  </ul>
</nav>

<section id=global-log>
  <h1>Log</h1>
  
  <pre><t:text value="$operation->{operation}->{data}"></pre>
</section>

<t:for as=$unit x="[values %{$operation->{units}}]">
  <article pl:id="'unit-' . $unit->{id}">
    <h1>Operation unit #<t:text value="$unit->{id}"></h1>

    <dl>
      <dt>Operation unit ID
      <dd><a pl:href="'#unit-' . $unit->{id}"><code><t:text value="$unit->{id}"></code></a>

      <dt>Host
      <dd><code><t:text value="$unit->{host}->{name}"></code>

      <dt>Status
      <dd><code><t:text value="$unit->{status}"></code>
      (<t:text value="
        {
          1 => 'Initial',
          2 => 'Started',
          3 => 'Failed',
          4 => 'Succeeded',
          5 => 'Precondition failed',
          6 => 'Skipped',
        }->{$unit->{status}} || $unit->{status}
      ">)

      <dt>Scheduled
      <dd><t:text value="
          $unit->{scheduled_timestamp}
              ? scalar gmtime $unit->{scheduled_timestamp}
              : ''
      ">

      <dt>Start
      <dd>
        <t:if x="$unit->{start_timestamp}">
          <time><t:text value="_datetime $unit->{start_timestamp}"></time>
        <t:else>
          -
        </t:if>

      <dt>End
      <dd>
        <t:if x="$unit->{end_timestamp}">
          <time><t:text value="_datetime $unit->{end_timestamp}"></time>
        <t:else>
          -
        </t:if>
    </dl>

    <article pl:id="'unit-' . $unit->{id} . '-log'">
      <h1>Log</h1>
  
      <pre><t:text value="$unit->{data}"></pre>
    </section>
  </article>
</t:for>

<script src="http://suika.fam.cx/www/style/ui/time.js.u8" charset=utf-8></script><script>
  new TER (document.body);
</script>
