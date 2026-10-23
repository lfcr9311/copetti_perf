<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="INPUT_FILE">
		<html>
			<head>
				<style type="text/css">td,th {font-family: courier}</style>
			</head>
			<body>
				<table border="1" style="border-collapse: collapse">
					<!-- INTERFACE VERSION, SECURITY CODE, SPEC VERSIONS -->
					<tr>
						<th width="220" align="left" >INTERFACE_VERSION</th>
						<td width="40" align="center">=</td>
						<td width="*" align="left" ><xsl:value-of select="interface_version"/></td>
					</tr>
					<tr>
						<th width="220" align="left" >SECURITY_CODE</th>
						<td width="40" align="center">=</td>
						<td width="*" align="left" >"<xsl:value-of select="security_code"/>"</td>
					</tr>
					<xsl:if test="takeoff_spec_version != ''">
						<tr>
							<th width="220" align="left" >TAKEOFF_SPEC_VERSION</th>
							<td width="40" align="center">=</td>
							<td width="*" align="left" ><xsl:value-of select="takeoff_spec_version"/></td>
						</tr>
					</xsl:if>
					<xsl:if test="landing_spec_version != ''">
						<tr>
							<th width="220" align="left" >LANDING_SPEC_VERSION</th>
							<td width="40" align="center">=</td>
							<td width="*" align="left" ><xsl:value-of select="landing_spec_version"/></td>
						</tr>
					</xsl:if>
					<tr><td colspan="100%"><br /></td></tr>
					<tr><th colspan="100%" align="left">CONFIG</th></tr>
					<!-- CONFIGURATION INFORMATION -->
					<xsl:if test="config != ''">
						<xsl:if test="config/output_file != ''">
							<tr>
								<td width="220" align="left" >OUTPUT_FILE</td>
								<td width="40" align="center">=</td>
								<td width="*" align="left" >"<xsl:value-of select="config/output_file"/>"</td>
							</tr>
						</xsl:if>
						<xsl:if test="config/trace_file != ''">
							<tr>
								<td width="220" align="left" >TRACE_FILE</td>
								<td width="40" align="center">=</td>
								<td width="*" align="left" >"<xsl:value-of select="config/trace_file"/>"</td>
							</tr>
						</xsl:if>
						<xsl:if test="config/program_files != ''">
							<tr>
								<td width="220" align="left" >PROGRAM_FILES</td>
								<td width="40" align="center">=</td>
								<td width="*" align="left" >"<xsl:value-of select="config/program_files"/>"</td>
							</tr>
						</xsl:if>
						<xsl:if test="config/data_files != ''">
							<tr>
								<td width="220" align="left" >DATA_FILES</td>
								<td width="40" align="center">=</td>
								<td width="*" align="left" >"<xsl:value-of select="config/data_files"/>"</td>
							</tr>
						</xsl:if>
					</xsl:if>
				</table>
				<br />
				<!-- COMMON BLOCK ARRAYS/ELEMENTS -->
				<!-- Loop through each block -->
				<xsl:for-each select="block">
					<table border="1" style="border-collapse: collapse">
						<tr><th colspan="100%" align="left"><xsl:value-of select="@type"/><xsl:text> </xsl:text><xsl:value-of select="@id"/></th></tr>
						<!-- Loop through each case -->
						<xsl:for-each select="case">
							<tr><th colspan="100%" align="left">CASE <xsl:value-of select="@id"/></th></tr>
							<!-- Loop through each case child -->
							<xsl:for-each select="child::*">
								<xsl:choose>
									<!-- If child is an array -->
									<xsl:when test="self::array">
										<xsl:for-each select="item">
										<tr>
											<td width="75" align="left" ><xsl:value-of select="../@name"/></td>
											<td width="50" align="right" >(<xsl:value-of select="@index"/>)</td>
											<td width="40" align="center">=</td>
											<td width="200" align="left" ><xsl:value-of select="value"/></td>
											<td width="*" align="left" >'<xsl:value-of select="description"/></td>
										</tr>
										</xsl:for-each>
									</xsl:when>
									<!-- If child is an element -->
									<xsl:when test="self::element">
										<tr>
											<td width="75" align="left" ><xsl:value-of select="@name"/></td>
											<td width="50" align="right" ><xsl:value-of select="@index"/></td>
											<td	width="40" align="center">=</td> <td width="200" align="left" ><xsl:value-of select="value"/></td>
											<td width="*" align="left" >'<xsl:value-of select="description"/></td>
										</tr>
									</xsl:when>
								</xsl:choose>
							</xsl:for-each>
							<tr><td colspan="100%"><br /></td></tr>
						</xsl:for-each>
					</table>
					<br />
				</xsl:for-each>
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>