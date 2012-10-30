<!DOCTYPE html>
<html t:params=$operations>
<t:call x="use URL::PercentEncode qw(percent_encode_c)">
<title>Cennel recent operations</title>
<t:call x="
sub _datetime ($) {
    my @time = gmtime $_[0];
    return sprintf '%04d-%02d-%02dT%02d:%02d:%02d-00:00',
        $time[5] + 1900, $time[4] + 1, $time[3], $time[2], $time[1], $time[0];
}
">

<h1>Cennel recent operations</h1>

<table>
  <tbody>
    <t:for as=$op x=$operations>
      <tr>
        <th><a pl:href="'/cennel/logs/' . $op->{operation}->{id}"><code><t:text value="$op->{operation}->{id}"></code></a>
        <td>
          <p><a pl:href="'/repos?repository_url=' . percent_encode_c $op->{repository}->{url}"><t:text value="$op->{repository}->{url}"></a>
          <p><a pl:href="'/repos/commits?repository_url=' . (percent_encode_c $op->{repository}->{url}) . '&sha=' . percent_encode_c $op->{repository}->{sha}"><t:text value="substr $op->{repository}->{sha}, 0, 10"></a>
          (<a pl:href="'/repos/commits?repository_url=' . (percent_encode_c $op->{repository}->{url}) . '&sha=' . percent_encode_c $op->{repository}->{branch}"><t:text value="$op->{repository}->{branch}"></a>)
        <td>
          <p>@<t:text value="$op->{role}->{name}">
          <p><t:text value="$op->{task}->{name}">
        <td>
          <code><t:text value="$op->{operation}->{status}"></code>
          (<t:text value="
            {
              1 => 'Initial',
              2 => 'Started',
              3 => 'Failed',
              4 => 'Succeeded',
              5 => 'Precondition failed',
              6 => 'Skipped',
              7 => 'Reverted',
            }->{$op->{operation}->{status}} || $op->{operation}->{status}
          ">)
        <td>
          <p>
            <t:if x="$op->{operation}->{start_timestamp}">
              <time><t:text value="_datetime $op->{operation}->{start_timestamp}"></time>
            <t:else>
              -
            </t:if>
          <p>
            <t:if x="$op->{operation}->{end_timestamp}">
              <time><t:text value="_datetime $op->{operation}->{end_timestamp}"></time>
            <t:else>
              -
            </t:if>
    </t:for>
</table>

<script src="http://suika.fam.cx/www/style/ui/time.js.u8" charset=utf-8></script><script>
  new TER (document.body);
</script>
